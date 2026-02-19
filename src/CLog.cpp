#include "CLog.hpp"

#include <amx/amx.h>
#include <amx/amx2.h>
#include <sdk.hpp>

#include <cstdio>
#include <utility>

namespace
{
constexpr unsigned int DEFAULT_LOG_MASK =
	static_cast<unsigned int>(MySQLLogLevel::WARNING)
	| static_cast<unsigned int>(MySQLLogLevel::ERROR);

::LogLevel ToOmpLevel(MySQLLogLevel level)
{
	switch (level)
	{
	case MySQLLogLevel::DEBUG:
		return ::LogLevel::Debug;
	case MySQLLogLevel::INFO:
		return ::LogLevel::Message;
	case MySQLLogLevel::WARNING:
		return ::LogLevel::Warning;
	case MySQLLogLevel::ERROR:
		return ::LogLevel::Error;
	case MySQLLogLevel::NONE:
	default:
		return ::LogLevel::Message;
	}
}

bool ReadBoolConfig(ICore *core, const char *key, bool default_value)
{
	if (core == nullptr)
		return default_value;

	IConfig &config = core->getConfig();
	if (bool *value = config.getBool(key))
		return *value;
	if (int *value = config.getInt(key))
		return *value != 0;

	return default_value;
}
} // namespace


void CDebugInfoManager::Update(AMX * const amx, const char *func)
{
	m_Amx = amx;
	m_NativeName = func;
	m_Info.clear();
	m_Available = false;
}

void CDebugInfoManager::Clear()
{
	m_Amx = nullptr;
	m_NativeName = nullptr;
	m_Available = false;
}

CLog::~CLog()
{
	Flush();
}

bool CLog::IsLogLevel(MySQLLogLevel level)
{
	std::lock_guard<std::mutex> lock_guard(m_StateMutex);
	return m_Enabled && HasLogLevel(m_LogMask, level);
}

void CLog::SetCore(ICore *core)
{
	{
		std::lock_guard<std::mutex> lock_guard(m_StateMutex);
		m_Core = core;
	}
	ConfigureFromCore();
}

void CLog::ConfigureFromCore()
{
	ICore *core = nullptr;
	{
		std::lock_guard<std::mutex> lock_guard(m_StateMutex);
		core = m_Core;
	}

	const bool enabled = ReadBoolConfig(core, "logging.mysql", true);
	const bool enable_debug = ReadBoolConfig(core, "logging.mysql_debug", false);
	const bool enable_info = ReadBoolConfig(core, "logging.mysql_info", false);
	const bool enable_warning = ReadBoolConfig(core, "logging.mysql_warning", true);
	const bool enable_error = ReadBoolConfig(core, "logging.mysql_error", true);

	unsigned int log_mask = 0;
	if (enable_debug)
		log_mask |= static_cast<unsigned int>(MySQLLogLevel::DEBUG);
	if (enable_info)
		log_mask |= static_cast<unsigned int>(MySQLLogLevel::INFO);
	if (enable_warning)
		log_mask |= static_cast<unsigned int>(MySQLLogLevel::WARNING);
	if (enable_error)
		log_mask |= static_cast<unsigned int>(MySQLLogLevel::ERROR);

	std::lock_guard<std::mutex> lock_guard(m_StateMutex);
	m_Enabled = enabled;
	m_LogMask = (log_mask == 0) ? DEFAULT_LOG_MASK : log_mask;
}

void CLog::Enqueue(MySQLLogLevel level, string &&message)
{
	std::lock_guard<std::mutex> lock_guard(m_QueueMutex);
	m_PendingLogs.push_back({ level, std::move(message) });
}

void CLog::Emit(MySQLLogLevel level, const string &message)
{
	ICore *core = nullptr;
	{
		std::lock_guard<std::mutex> lock_guard(m_StateMutex);
		core = m_Core;
	}

	if (core != nullptr)
	{
		core->logLn(ToOmpLevel(level), "[mysql] %s", message.c_str());
		return;
	}

	FILE *stream = (level == MySQLLogLevel::ERROR) ? stderr : stdout;
	std::fprintf(stream, "[mysql] %s\n", message.c_str());
	std::fflush(stream);
}

void CLog::Flush()
{
	std::vector<PendingLogEntry> log_entries;
	{
		std::lock_guard<std::mutex> lock_guard(m_QueueMutex);
		if (m_PendingLogs.empty())
			return;
		log_entries.swap(m_PendingLogs);
	}

	for (auto const &entry : log_entries)
		Emit(entry.level, entry.message);
}

CScopedDebugInfo::CScopedDebugInfo(AMX * const amx, const char *func,
	cell * const params, const char *params_format /* = ""*/)
{
	CDebugInfoManager::Get()->Update(amx, func);

	if (!CLog::Get()->IsLogLevel(MySQLLogLevel::DEBUG))
		return;

	if (amx == nullptr || params == nullptr || func == nullptr)
		return;

	string call_str = fmt::format("{}(", func);
	if (params_format != nullptr)
	{
		for (size_t i = 0; params_format[i] != '\0'; ++i)
		{
			if (i != 0)
				call_str += ", ";

			cell current_param = params[i + 1];
			switch (params_format[i])
			{
			case 'd': // decimal
			case 'i': // integer
				call_str += fmt::format("{}", static_cast<int>(current_param));
				break;
			case 'f': // float
				call_str += fmt::format("{}", amx_ctof(current_param));
				break;
			case 'h': // hexadecimal
			case 'x':
				call_str += fmt::format("{:x}", current_param);
				break;
			case 'b': // binary
				call_str += fmt::format("{:b}", current_param);
				break;
			case 's': // string
				call_str += fmt::format("\"{}\"", amx_GetCppString(amx, current_param));
				break;
			case '*': // censored output
				call_str += "\"*****\"";
				break;
			case 'r': // reference
			{
				cell *address = nullptr;
				amx_GetAddr(amx, current_param, &address);
				call_str += fmt::format("{:#08x}", reinterpret_cast<uintptr_t>(address));
			}	break;
			case 'p': // pointer-value
				call_str += fmt::format("{:#08x}", static_cast<unsigned int>(current_param));
				break;
			default:
				call_str += "?";
				break;
			}
		}
	}
	call_str += ")";

	CLog::Get()->Log(MySQLLogLevel::DEBUG, "{}", call_str);
}
