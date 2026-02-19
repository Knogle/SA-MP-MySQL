#include "plugin_runtime.hpp"

#include "CHandle.hpp"
#include "CCallback.hpp"
#include "CResult.hpp"
#include "CDispatcher.hpp"
#include "COptions.hpp"
#include "COrm.hpp"
#include "CLog.hpp"

void DestroyPluginRuntime()
{
	COrmManager::CSingleton::Destroy();
	CHandleManager::CSingleton::Destroy();
	CCallbackManager::CSingleton::Destroy();
	CResultSetManager::CSingleton::Destroy();
	CDispatcher::CSingleton::Destroy();
	COptionManager::CSingleton::Destroy();
	CLog::CSingleton::Destroy();
}
