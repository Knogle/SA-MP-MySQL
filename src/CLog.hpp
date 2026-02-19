#pragma once

#include "CSingleton.hpp"
#include "CError.hpp"

#include <fmt/format.h>
#include <amx/amx.h>

#include <string>
#include <cstdint>
#include <mutex>
#include <utility>
#include <vector>

using std::string;

struct ICore;

enum class MySQLLogLevel : unsigned int
{
	NONE = 0,
	DEBUG = 1,
	INFO = 2,
	WARNING = 4,
	ERROR = 8,
};

inline MySQLLogLevel operator|(MySQLLogLevel lhs, MySQLLogLevel rhs)
{
	return static_cast<MySQLLogLevel>(
		static_cast<unsigned int>(lhs) | static_cast<unsigned int>(rhs));
}

inline MySQLLogLevel &operator|=(MySQLLogLevel &lhs, MySQLLogLevel rhs)
{
	lhs = lhs | rhs;
	return lhs;
}

inline bool HasLogLevel(unsigned int level_mask, MySQLLogLevel level)
{
	return (level_mask & static_cast<unsigned int>(level))
		== static_cast<unsigned int>(level);
}

struct AmxFuncCallInfo
{
	int line = 0;
	const char *file = nullptr;
	const char *function = nullptr;
};


class CDebugInfoManager : public CSingleton<CDebugInfoManager>
{
	friend class CSingleton<CDebugInfoManager>;
	friend class CScopedDebugInfo;
private:
	CDebugInfoManager() = default;
	~CDebugInfoManager() = default;

private:
	bool m_Available = false;

	AMX *m_Amx = nullptr;
	std::vector<AmxFuncCallInfo> m_Info;
	const char *m_NativeName = nullptr;

private:
	void Update(AMX * const amx, const char *func);
	void Clear();

public:
	inline AMX * const GetCurrentAmx()
	{
		return m_Amx;
	}
	inline const decltype(m_Info) &GetCurrentInfo()
	{
		return m_Info;
	}
	inline bool IsInfoAvailable()
	{
		return m_Available;
	}
	inline const char *GetCurrentNativeName()
	{
		return m_NativeName;
	}
};


class CLog : public CSingleton<CLog>
{
	friend class CSingleton<CLog>;
	friend class CScopedDebugInfo;
private:
	struct PendingLogEntry
	{
		MySQLLogLevel level = MySQLLogLevel::NONE;
		string message;
	};

	CLog() = default;
	~CLog();

public:
	bool IsLogLevel(MySQLLogLevel level);

	void SetCore(ICore *core);
	void ConfigureFromCore();
	void Flush();

private:
	void Enqueue(MySQLLogLevel level, string &&message);
	void Emit(MySQLLogLevel level, const string &message);

public:
	inline bool IsLogLevelFast(MySQLLogLevel level)
	{
		return HasLogLevel(m_LogMask, level);
	}

	template<typename... Args>
	inline void Log(MySQLLogLevel level, const char *format, Args &&...args)
	{
		if (!IsLogLevel(level))
			return;

		string str = format;
		if (sizeof...(args) != 0)
			str = fmt::format(format, std::forward<Args>(args)...);

		Enqueue(level, std::move(str));
	}

	template<typename... Args>
	inline void Log(MySQLLogLevel level,
					std::vector<AmxFuncCallInfo> const &callinfo,
					const char *format, Args &&...args)
	{
		if (!IsLogLevel(level))
			return;

		string str = format;
		if (sizeof...(args) != 0)
			str = fmt::format(format, std::forward<Args>(args)...);

		if (!callinfo.empty())
		{
			str += " (";
			bool first = true;
			for (auto const &info : callinfo)
			{
				if (!first)
					str += " -> ";
				str += fmt::format("{}:{}",
					info.file ? info.file : "(unknown)",
					info.line);
				first = false;
			}
			str += ")";
		}

		Enqueue(level, std::move(str));
	}

	// should only be called in native functions
	template<typename... Args>
	void LogNative(MySQLLogLevel level, const char *fmt, Args &&...args)
	{
		if (!IsLogLevel(level))
			return;

		if (CDebugInfoManager::Get()->GetCurrentAmx() == nullptr)
			return; //do nothing, since we're not called from within a native func

		string msg = fmt::format("{}: {}",
			CDebugInfoManager::Get()->GetCurrentNativeName(),
			fmt::format(fmt, std::forward<Args>(args)...));

		if (CDebugInfoManager::Get()->IsInfoAvailable())
			Log(level, CDebugInfoManager::Get()->GetCurrentInfo(), msg.c_str());
		else
			Log(level, msg.c_str());
	}

	template<typename T>
	inline void LogNative(const CError<T> &error)
	{
		LogNative(MySQLLogLevel::ERROR, "{} error: {}",
				  error.module(), error.msg());
	}

private:
	ICore *m_Core = nullptr;
	bool m_Enabled = true;
	unsigned int m_LogMask = static_cast<unsigned int>(MySQLLogLevel::WARNING)
		| static_cast<unsigned int>(MySQLLogLevel::ERROR);

	std::mutex m_StateMutex;
	std::mutex m_QueueMutex;
	std::vector<PendingLogEntry> m_PendingLogs;

};


class CScopedDebugInfo
{
public:
	CScopedDebugInfo(AMX * const amx, const char *func,
		cell * const params, const char *params_format = "");
	~CScopedDebugInfo()
	{
		CDebugInfoManager::Get()->Clear();
	}
	CScopedDebugInfo(const CScopedDebugInfo &rhs) = delete;
};
