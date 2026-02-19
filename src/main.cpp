#include <sdk.hpp>
#include <Server/Components/Pawn/pawn.hpp>
#include <samplog/Api.hpp>

#include "amx_sdk.hpp"
#include "natives.hpp"
#include "CHandle.hpp"
#include "CCallback.hpp"
#include "CResult.hpp"
#include "CDispatcher.hpp"
#include "COptions.hpp"
#include "COrm.hpp"
#include "plugin_runtime.hpp"
#include "version.hpp"

#include "mysql.hpp"

extern void *pAMXFunctions;

extern "C" const AMX_NATIVE_INFO native_list[] =
{
	AMX_DEFINE_NATIVE(orm_create)
	AMX_DEFINE_NATIVE(orm_destroy)

	AMX_DEFINE_NATIVE(orm_errno)

	AMX_DEFINE_NATIVE(orm_apply_cache)

	AMX_DEFINE_NATIVE(orm_select)
	AMX_DEFINE_NATIVE(orm_update)
	AMX_DEFINE_NATIVE(orm_insert)
	AMX_DEFINE_NATIVE(orm_delete)

	AMX_DEFINE_NATIVE(orm_save)

	AMX_DEFINE_NATIVE(orm_addvar_int)
	AMX_DEFINE_NATIVE(orm_addvar_float)
	AMX_DEFINE_NATIVE(orm_addvar_string)

	AMX_DEFINE_NATIVE(orm_clear_vars)
	AMX_DEFINE_NATIVE(orm_delvar)
	AMX_DEFINE_NATIVE(orm_setkey)


	AMX_DEFINE_NATIVE(mysql_connect)
	AMX_DEFINE_NATIVE(mysql_connect_file)
	AMX_DEFINE_NATIVE(mysql_close)

	AMX_DEFINE_NATIVE(mysql_unprocessed_queries)
	AMX_DEFINE_NATIVE(mysql_global_options)

	AMX_DEFINE_NATIVE(mysql_init_options)
	AMX_DEFINE_NATIVE(mysql_set_option)

	AMX_DEFINE_NATIVE(mysql_pquery)
	AMX_DEFINE_NATIVE(mysql_tquery)
	AMX_DEFINE_NATIVE(mysql_query)
	AMX_DEFINE_NATIVE(mysql_tquery_file)
	AMX_DEFINE_NATIVE(mysql_query_file)

	AMX_DEFINE_NATIVE(mysql_errno)
	AMX_DEFINE_NATIVE(mysql_error)
	AMX_DEFINE_NATIVE(mysql_escape_string)
	AMX_DEFINE_NATIVE(mysql_format)
	AMX_DEFINE_NATIVE(mysql_get_charset)
	AMX_DEFINE_NATIVE(mysql_set_charset)
	AMX_DEFINE_NATIVE(mysql_stat)


	AMX_DEFINE_NATIVE(cache_get_row_count)
	AMX_DEFINE_NATIVE(cache_get_field_count)
	AMX_DEFINE_NATIVE(cache_get_result_count)
	AMX_DEFINE_NATIVE(cache_get_field_name)
	AMX_DEFINE_NATIVE(cache_get_field_type)
	AMX_DEFINE_NATIVE(cache_set_result)

	AMX_DEFINE_NATIVE(cache_get_value_index)
	AMX_DEFINE_NATIVE(cache_get_value_index_int)
	AMX_DEFINE_NATIVE(cache_get_value_index_float)
	AMX_DEFINE_NATIVE(cache_is_value_index_null)

	AMX_DEFINE_NATIVE(cache_get_value_name)
	AMX_DEFINE_NATIVE(cache_get_value_name_int)
	AMX_DEFINE_NATIVE(cache_get_value_name_float)
	AMX_DEFINE_NATIVE(cache_is_value_name_null)

	AMX_DEFINE_NATIVE(cache_save)
	AMX_DEFINE_NATIVE(cache_delete)
	AMX_DEFINE_NATIVE(cache_set_active)
	AMX_DEFINE_NATIVE(cache_unset_active)
	AMX_DEFINE_NATIVE(cache_is_any_active)
	AMX_DEFINE_NATIVE(cache_is_valid)

	AMX_DEFINE_NATIVE(cache_affected_rows)
	AMX_DEFINE_NATIVE(cache_insert_id)
	AMX_DEFINE_NATIVE(cache_warning_count)

	AMX_DEFINE_NATIVE(cache_get_query_exec_time)
	AMX_DEFINE_NATIVE(cache_get_query_string)
	{ nullptr, nullptr }
};

namespace
{
	class MySQLOmpComponent final : public IComponent, public CoreEventHandler, public PawnEventHandler
	{
		PROVIDE_UID(0x6d7973716c6f6d70);

	public:
		StringView componentName() const override
		{
			return "open.mp mysql";
		}

		SemanticVersion componentVersion() const override
		{
			return SemanticVersion(41, 4, 0, 0);
		}

		void onLoad(ICore *core) override
		{
			core_ = core;
			if (mysql_library_init(0, nullptr, nullptr) != 0)
			{
				core_->logLn(LogLevel::Error,
					"component.mysql: can't initialize MySQL library.");
				return;
			}

			mysql_initialized_ = true;
			core_->printLn(" >> component.mysql: %s successfully loaded.", MYSQL_VERSION);
		}

		void onInit(IComponentList *components) override
		{
			if (!mysql_initialized_)
			{
				return;
			}

			pawn_component_ = components->queryComponent<IPawnComponent>();
			if (pawn_component_ == nullptr)
			{
				core_->logLn(LogLevel::Error,
					"component.mysql: Pawn component not loaded.");
				return;
			}

			pAMXFunctions = static_cast<void *>(
				const_cast<void **>(pawn_component_->getAmxFunctions().data()));

			pawn_component_->getEventDispatcher().addEventHandler(this);
			core_->getEventDispatcher().addEventHandler(this);
			events_registered_ = true;

			if (IPawnScript *script = pawn_component_->mainScript())
			{
				RegisterScript(*script);
			}
			for (IPawnScript *script : pawn_component_->sideScripts())
			{
				if (script != nullptr)
				{
					RegisterScript(*script);
				}
			}
		}

		void onTick(Microseconds elapsed, TimePoint now) override
		{
			(void)elapsed;
			(void)now;
			if (mysql_initialized_)
			{
				CDispatcher::Get()->Process();
			}
		}

		void onAmxLoad(IPawnScript &script) override
		{
			if (mysql_initialized_)
			{
				RegisterScript(script);
			}
		}

		void onAmxUnload(IPawnScript &script) override
		{
			if (mysql_initialized_)
			{
				UnregisterScript(script);
			}
		}

		void onFree(IComponent *component) override
		{
			if (component == pawn_component_)
			{
				pawn_component_ = nullptr;
				pAMXFunctions = nullptr;
			}
		}

		void reset() override
		{
		}

		void free() override
		{
			Shutdown();
			delete this;
		}

		~MySQLOmpComponent() override = default;

	private:
		void RegisterScript(IPawnScript &script)
		{
			AMX *amx = script.GetAMX();
			if (amx == nullptr)
			{
				return;
			}

			samplog::Api::Get()->RegisterAmx(amx);
			CCallbackManager::Get()->AddAmx(amx);

			const int error = amx_Register(amx, native_list, -1);
			if (error != AMX_ERR_NONE)
			{
				core_->logLn(LogLevel::Error,
					"component.mysql: amx_Register failed (error %d).",
					error);
			}
		}

		void UnregisterScript(IPawnScript &script)
		{
			AMX *amx = script.GetAMX();
			if (amx == nullptr)
			{
				return;
			}

			samplog::Api::Get()->EraseAmx(amx);
			CCallbackManager::Get()->RemoveAmx(amx);
		}

		void Shutdown()
		{
			if (events_registered_)
			{
				if (pawn_component_ != nullptr)
				{
					pawn_component_->getEventDispatcher().removeEventHandler(this);
				}
				if (core_ != nullptr)
				{
					core_->getEventDispatcher().removeEventHandler(this);
				}
				events_registered_ = false;
			}

			if (!mysql_initialized_)
			{
				pAMXFunctions = nullptr;
				return;
			}

			if (core_ != nullptr)
			{
				core_->printLn("component.mysql: Unloading component...");
			}

			DestroyPluginRuntime();

			mysql_library_end();
			mysql_initialized_ = false;
			pAMXFunctions = nullptr;

			if (core_ != nullptr)
			{
				core_->printLn("component.mysql: Component unloaded.");
			}
		}

		ICore *core_ = nullptr;
		IPawnComponent *pawn_component_ = nullptr;
		bool mysql_initialized_ = false;
		bool events_registered_ = false;
	};
}

COMPONENT_ENTRY_POINT()
{
	return new MySQLOmpComponent();
}
