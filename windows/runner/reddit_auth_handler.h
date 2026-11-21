#ifndef RUNNER_REDDIT_AUTH_HANDLER_H_
#define RUNNER_REDDIT_AUTH_HANDLER_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

inline constexpr ULONG_PTR kSavedexAuthCallbackMessageId = 0x53564458;  // 'SVDX'
inline constexpr const wchar_t kSavedexAuthWindowPropName[] =
    L"me.neon16bit.savedex.auth_window";

// Returns true if |uri| starts with a valid, non-reserved custom scheme
// followed by "://" and fits within the IPC callback size limit.
bool IsCustomSchemeAuthUri(const std::string& uri);

// Forwards a custom-scheme callback URI from a secondary process invocation
// to an already-running Savedex window via WM_COPYDATA. Returns true if an
// existing window accepted the message (or focused as fallback).
bool ForwardAuthCallbackToRunningInstance(const std::string& uri);

// Handles temporary HKCU custom-scheme registration and OAuth callback delivery
// on MethodChannel('me.neon16bit.savedex/reddit_auth').
class RedditAuthHandler {
 public:
  RedditAuthHandler(HWND hwnd, flutter::BinaryMessenger* messenger);
  ~RedditAuthHandler();

  RedditAuthHandler(const RedditAuthHandler&) = delete;
  RedditAuthHandler& operator=(const RedditAuthHandler&) = delete;

  void Dispose();
  bool HandleCopyData(HWND hwnd, const COPYDATASTRUCT* cds);

 private:
  struct SavedRegistryValue {
    bool existed = false;
    DWORD type = REG_NONE;
    std::vector<BYTE> data;
  };

  struct SavedRegistryState {
    std::wstring scheme;
    bool created_by_savedex = false;
    SavedRegistryValue previous_default;
    SavedRegistryValue previous_url_protocol;
    bool shell_key_existed = false;
    bool open_key_existed = false;
    bool command_key_existed = false;
    SavedRegistryValue previous_command;
    SavedRegistryValue previous_delegate_execute;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CancelPendingAuth();
  bool RegisterCustomScheme(const std::wstring& scheme, std::string* error_out);
  void RestoreRegisteredScheme();
  static bool ReadRegistryRawValue(HKEY root,
                                   const std::wstring& subkey,
                                   const wchar_t* value_name,
                                   SavedRegistryValue* out);
  static bool WriteRegistryRawValue(HKEY key,
                                    const wchar_t* value_name,
                                    const SavedRegistryValue& val);

  HWND hwnd_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> pending_result_;
  std::string pending_scheme_;
  std::optional<SavedRegistryState> saved_registry_;
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
  uint64_t active_session_id_ = 0;
  bool disposed_ = false;
};

#endif  // RUNNER_REDDIT_AUTH_HANDLER_H_
