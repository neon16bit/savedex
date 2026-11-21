#include "reddit_auth_handler.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <algorithm>
#include <cctype>
#include <cwchar>
#include <vector>

namespace {

constexpr const wchar_t kSavedexWindowClassName[] =
    L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kSavedexProtocolDescription[] =
    L"URL:Savedex OAuth Redirect";
constexpr const wchar_t kSavedexOwnedMarkerValue[] =
    L"SavedexTemporaryScheme";
constexpr DWORD kMaxCallbackUriBytes = 32768;
constexpr DWORD kMaxRegistryValueBytes = 65536;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8.c_str(),
      static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  const int written = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8.c_str(),
      static_cast<int>(utf8.size()), wide.data(), length);
  if (written <= 0) {
    return std::wstring();
  }
  return wide;
}

std::wstring GetCurrentExePath() {
  DWORD capacity = MAX_PATH;
  while (capacity <= 32768) {
    std::vector<wchar_t> buffer(capacity, L'\0');
    const DWORD length =
        ::GetModuleFileNameW(nullptr, buffer.data(), capacity);
    if (length == 0) {
      return std::wstring();
    }
    if (length < capacity - 1) {
      return std::wstring(buffer.data(), length);
    }
    capacity *= 2;
  }
  return std::wstring();
}

std::string ToAsciiLower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return value;
}

bool StartsWithCaseInsensitive(const std::string& value,
                               const std::string& prefix) {
  if (value.size() < prefix.size()) {
    return false;
  }
  for (size_t i = 0; i < prefix.size(); ++i) {
    const unsigned char a = static_cast<unsigned char>(value[i]);
    const unsigned char b = static_cast<unsigned char>(prefix[i]);
    if (std::tolower(a) != std::tolower(b)) {
      return false;
    }
  }
  return true;
}

bool IsAllowedCustomScheme(const std::string& scheme) {
  if (scheme.empty() || scheme.size() > 64) {
    return false;
  }
  const unsigned char first = static_cast<unsigned char>(scheme[0]);
  if (first < 'a' || first > 'z') {
    return false;
  }
  for (size_t i = 1; i < scheme.size(); ++i) {
    const unsigned char ch = static_cast<unsigned char>(scheme[i]);
    const bool is_lower = (ch >= 'a' && ch <= 'z');
    const bool is_digit = (ch >= '0' && ch <= '9');
    if (!is_lower && !is_digit && ch != '+' && ch != '-' && ch != '.') {
      return false;
    }
  }

  static constexpr const char* kReservedSchemes[] = {
      "http",
      "https",
      "file",
      "ftp",
      "mailto",
      "tel",
      "javascript",
      "data",
      "vbscript",
      "about",
      "blob",
      "chrome",
      "edge",
      "ms-settings",
      "ms-windows-store",
      "shell",
      "search-ms",
      "cmd",
      "powershell",
      "explorer",
      "clsid",
      "interface",
      "typelib",
      "appid",
      "applications",
      "systemfileassociations",
      "directory",
      "drive",
      "folder",
      "exefile",
      "batfile",
      "cmdfile",
      "comfile",
      "lnkfile",
      "regfile",
      "txtfile",
      "htmlfile",
      "chromehtml",
      "msedgehtm",
      "firefoxurl",
      "microsoft-edge",
      "ms-edge",
      "localhost",
  };
  for (const char* reserved : kReservedSchemes) {
    if (scheme == reserved) {
      return false;
    }
  }
  return true;
}

bool IsSafeAuthUrl(const std::string& url) {
  if (!StartsWithCaseInsensitive(url, "https://") || url.size() <= 8) {
    return false;
  }
  const char first_host = url[8];
  if (first_host == '/' || first_host == '?' || first_host == '#') {
    return false;
  }
  for (unsigned char ch : url) {
    if (ch <= 0x20 || ch == 0x7F || ch == '"') {
      return false;
    }
  }
  return true;
}

bool RegistryKeyExists(HKEY root, const std::wstring& subkey) {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(root, subkey.c_str(), 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  ::RegCloseKey(key);
  return true;
}

bool WriteRegistryStringValue(HKEY key,
                              const wchar_t* value_name,
                              DWORD type,
                              const std::wstring& value) {
  const DWORD byte_size =
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  const LSTATUS status = ::RegSetValueExW(
      key, value_name, 0, type, reinterpret_cast<const BYTE*>(value.c_str()),
      byte_size);
  return status == ERROR_SUCCESS;
}

void SetCopyDataMessageFilter(HWND hwnd, DWORD action) {
  if (hwnd != nullptr && ::IsWindow(hwnd)) {
    ::ChangeWindowMessageFilterEx(hwnd, WM_COPYDATA, action, nullptr);
  }
}

void BringWindowToForeground(HWND hwnd, bool async_restore) {
  if (hwnd == nullptr || !::IsWindow(hwnd)) {
    return;
  }
  if (::IsIconic(hwnd)) {
    if (async_restore) {
      ::ShowWindowAsync(hwnd, SW_RESTORE);
    } else {
      ::ShowWindow(hwnd, SW_RESTORE);
    }
  }
  ::SetForegroundWindow(hwnd);
}

struct ForwardSearchContext {
  const std::string* uri = nullptr;
  HWND fallback_hwnd = nullptr;
  bool delivered = false;
};

BOOL CALLBACK EnumSavedexWindowsProc(HWND hwnd, LPARAM lparam) {
  auto* ctx = reinterpret_cast<ForwardSearchContext*>(lparam);
  if (ctx == nullptr || !::IsWindow(hwnd)) {
    return TRUE;
  }

  DWORD target_pid = 0;
  ::GetWindowThreadProcessId(hwnd, &target_pid);
  if (target_pid == 0 || target_pid == ::GetCurrentProcessId()) {
    return TRUE;
  }

  wchar_t class_name[64]{};
  if (::GetClassNameW(hwnd, class_name, 64) == 0 ||
      std::wcscmp(class_name, kSavedexWindowClassName) != 0) {
    return TRUE;
  }

  if (::GetPropW(hwnd, kSavedexAuthWindowPropName) == nullptr) {
    return TRUE;
  }

  if (ctx->fallback_hwnd == nullptr) {
    ctx->fallback_hwnd = hwnd;
  }

  ::AllowSetForegroundWindow(target_pid);

  COPYDATASTRUCT cds{};
  cds.dwData = kSavedexAuthCallbackMessageId;
  cds.cbData = static_cast<DWORD>(ctx->uri->size() + 1);
  cds.lpData = const_cast<char*>(ctx->uri->c_str());

  DWORD_PTR handled = 0;
  const LRESULT send_ok = ::SendMessageTimeoutW(
      hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds), SMTO_ABORTIFHUNG,
      3000, &handled);
  if (send_ok != 0 && handled != 0) {
    ctx->delivered = true;
    return FALSE;
  }

  return TRUE;
}

}  // namespace

bool IsCustomSchemeAuthUri(const std::string& uri) {
  if (uri.empty() || uri.size() >= kMaxCallbackUriBytes) {
    return false;
  }
  const size_t scheme_end = uri.find("://");
  if (scheme_end == std::string::npos || scheme_end == 0 || scheme_end > 64) {
    return false;
  }
  const std::string scheme = ToAsciiLower(uri.substr(0, scheme_end));
  return IsAllowedCustomScheme(scheme);
}

bool ForwardAuthCallbackToRunningInstance(const std::string& uri) {
  if (!IsCustomSchemeAuthUri(uri)) {
    return false;
  }

  ForwardSearchContext ctx;
  ctx.uri = &uri;
  ::EnumWindows(EnumSavedexWindowsProc, reinterpret_cast<LPARAM>(&ctx));
  if (ctx.delivered) {
    return true;
  }

  if (ctx.fallback_hwnd != nullptr) {
    BringWindowToForeground(ctx.fallback_hwnd, true);
    return true;
  }

  return false;
}

RedditAuthHandler::RedditAuthHandler(HWND hwnd,
                                     flutter::BinaryMessenger* messenger)
    : hwnd_(hwnd) {
  if (hwnd_ != nullptr) {
    ::SetPropW(hwnd_, kSavedexAuthWindowPropName, reinterpret_cast<HANDLE>(1));
  }
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "me.neon16bit.savedex/reddit_auth",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

RedditAuthHandler::~RedditAuthHandler() {
  Dispose();
}

void RedditAuthHandler::Dispose() {
  if (disposed_) {
    return;
  }
  disposed_ = true;
  *alive_ = false;

  if (hwnd_ != nullptr) {
    ::RemovePropW(hwnd_, kSavedexAuthWindowPropName);
  }

  SetCopyDataMessageFilter(hwnd_, MSGFLT_RESET);

  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }

  CancelPendingAuth();
}

void RedditAuthHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "startDesktopCustomSchemeAuth") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args == nullptr) {
      result->Error("INVALID_ARGS", "Expected map arguments for OAuth launch.");
      return;
    }

    const auto auth_it = args->find(flutter::EncodableValue("authUrl"));
    const auto scheme_it =
        args->find(flutter::EncodableValue("callbackScheme"));
    const std::string* raw_auth_url =
        (auth_it != args->end())
            ? std::get_if<std::string>(&auth_it->second)
            : nullptr;
    const std::string* raw_scheme =
        (scheme_it != args->end())
            ? std::get_if<std::string>(&scheme_it->second)
            : nullptr;

    if (raw_auth_url == nullptr || raw_scheme == nullptr) {
      result->Error("INVALID_ARGS",
                    "Missing authUrl or callbackScheme argument.");
      return;
    }

    const std::string scheme = ToAsciiLower(*raw_scheme);
    if (!IsAllowedCustomScheme(scheme) || !IsSafeAuthUrl(*raw_auth_url)) {
      result->Error("INVALID_REDIRECT_URI",
                    "Invalid custom callback scheme or authorization URL.");
      return;
    }

    const std::wstring scheme_wide = Utf16FromUtf8(scheme);
    const std::wstring auth_url_wide = Utf16FromUtf8(*raw_auth_url);
    if (scheme_wide.empty() || auth_url_wide.empty()) {
      result->Error("INVALID_REDIRECT_URI", "Invalid authorization URL.");
      return;
    }

    CancelPendingAuth();

    std::string reg_error;
    if (!RegisterCustomScheme(scheme_wide, &reg_error)) {
      result->Error("SCHEME_REGISTER_FAILED", reg_error);
      return;
    }

    SetCopyDataMessageFilter(hwnd_, MSGFLT_ALLOW);

    const uint64_t session_id = ++active_session_id_;
    pending_result_ = std::move(result);
    pending_scheme_ = scheme;
    const auto alive = alive_;
    const HWND hwnd = hwnd_;

    SHELLEXECUTEINFOW sei{};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_FLAG_NO_UI;
    sei.hwnd = hwnd;
    sei.lpVerb = L"open";
    sei.lpFile = auth_url_wide.c_str();
    sei.nShow = SW_SHOWNORMAL;

    const BOOL launched = ::ShellExecuteExW(&sei);
    if (!*alive) {
      return;
    }

    if (!launched && active_session_id_ == session_id && pending_result_) {
      auto failed_result = std::move(pending_result_);
      pending_scheme_.clear();
      RestoreRegisteredScheme();
      SetCopyDataMessageFilter(hwnd_, MSGFLT_RESET);
      failed_result->Error("BROWSER_LAUNCH_FAILED",
                           "Could not open system browser.");
    }
    return;
  }

  if (method == "cancelDesktopCustomSchemeAuth") {
    CancelPendingAuth();
    result->Success();
    return;
  }

  result->NotImplemented();
}

bool RedditAuthHandler::HandleCopyData(HWND hwnd, const COPYDATASTRUCT* cds) {
  (void)hwnd;
  if (cds == nullptr || cds->dwData != kSavedexAuthCallbackMessageId ||
      cds->lpData == nullptr || cds->cbData <= 1 ||
      cds->cbData > kMaxCallbackUriBytes) {
    return false;
  }

  if (!pending_result_) {
    return false;
  }

  const char* raw_data = static_cast<const char*>(cds->lpData);
  std::string uri(raw_data, static_cast<size_t>(cds->cbData));
  const size_t nul_pos = uri.find('\0');
  if (nul_pos != std::string::npos) {
    uri.resize(nul_pos);
  }
  if (uri.empty()) {
    return false;
  }

  const std::string expected_prefix = pending_scheme_ + "://";
  if (!StartsWithCaseInsensitive(uri, expected_prefix)) {
    return false;
  }

  auto result = std::move(pending_result_);
  pending_scheme_.clear();
  ++active_session_id_;
  RestoreRegisteredScheme();
  SetCopyDataMessageFilter(hwnd_, MSGFLT_RESET);
  BringWindowToForeground(hwnd_, false);
  result->Success(flutter::EncodableValue(uri));
  return true;
}

void RedditAuthHandler::CancelPendingAuth() {
  auto result = std::move(pending_result_);
  pending_scheme_.clear();
  ++active_session_id_;
  RestoreRegisteredScheme();
  SetCopyDataMessageFilter(hwnd_, MSGFLT_RESET);
  if (result) {
    result->Error("CANCELED", "Authorization was canceled.");
  }
}

bool RedditAuthHandler::ReadRegistryRawValue(HKEY root,
                                             const std::wstring& subkey,
                                             const wchar_t* value_name,
                                             SavedRegistryValue* out) {
  out->existed = false;
  out->type = REG_NONE;
  out->data.clear();

  HKEY key = nullptr;
  const LSTATUS open_status =
      ::RegOpenKeyExW(root, subkey.c_str(), 0, KEY_READ, &key);
  if (open_status == ERROR_FILE_NOT_FOUND) {
    return true;
  }
  if (open_status != ERROR_SUCCESS) {
    return false;
  }

  DWORD type = REG_NONE;
  DWORD bytes = 0;
  LSTATUS query_status =
      ::RegQueryValueExW(key, value_name, nullptr, &type, nullptr, &bytes);
  if (query_status == ERROR_FILE_NOT_FOUND) {
    ::RegCloseKey(key);
    return true;
  }
  if (query_status != ERROR_SUCCESS || bytes > kMaxRegistryValueBytes) {
    ::RegCloseKey(key);
    return false;
  }

  std::vector<BYTE> data(bytes);
  if (bytes > 0) {
    query_status =
        ::RegQueryValueExW(key, value_name, nullptr, &type, data.data(), &bytes);
    if (query_status != ERROR_SUCCESS) {
      ::RegCloseKey(key);
      return false;
    }
    data.resize(bytes);
  }

  ::RegCloseKey(key);
  out->existed = true;
  out->type = type;
  out->data = std::move(data);
  return true;
}

bool RedditAuthHandler::WriteRegistryRawValue(HKEY key,
                                              const wchar_t* value_name,
                                              const SavedRegistryValue& val) {
  const BYTE* ptr = val.data.empty() ? nullptr : val.data.data();
  const LSTATUS status = ::RegSetValueExW(
      key, value_name, 0, val.type, ptr, static_cast<DWORD>(val.data.size()));
  return status == ERROR_SUCCESS;
}

bool RedditAuthHandler::RegisterCustomScheme(const std::wstring& scheme,
                                             std::string* error_out) {
  RestoreRegisteredScheme();

  const std::wstring exe_path = GetCurrentExePath();
  if (exe_path.empty()) {
    if (error_out != nullptr) {
      *error_out = "Could not locate executable path for protocol handler.";
    }
    return false;
  }

  SavedRegistryState state;
  state.scheme = scheme;

  const std::wstring scheme_subkey = L"Software\\Classes\\" + scheme;
  const std::wstring shell_subkey = scheme_subkey + L"\\shell";
  const std::wstring open_subkey = shell_subkey + L"\\open";
  const std::wstring cmd_subkey = open_subkey + L"\\command";

  if (RegistryKeyExists(HKEY_CURRENT_USER, scheme_subkey)) {
    SavedRegistryValue owned_marker;
    if (!ReadRegistryRawValue(HKEY_CURRENT_USER, scheme_subkey,
                              kSavedexOwnedMarkerValue, &owned_marker)) {
      if (error_out != nullptr) {
        *error_out = "Failed to inspect existing HKCU registry key.";
      }
      return false;
    }

    if (owned_marker.existed) {
      state.created_by_savedex = true;
    } else {
      state.shell_key_existed =
          RegistryKeyExists(HKEY_CURRENT_USER, shell_subkey);
      state.open_key_existed =
          RegistryKeyExists(HKEY_CURRENT_USER, open_subkey);
      state.command_key_existed =
          RegistryKeyExists(HKEY_CURRENT_USER, cmd_subkey);

      if (!ReadRegistryRawValue(HKEY_CURRENT_USER, scheme_subkey, nullptr,
                                &state.previous_default) ||
          !ReadRegistryRawValue(HKEY_CURRENT_USER, scheme_subkey,
                                L"URL Protocol",
                                &state.previous_url_protocol) ||
          !ReadRegistryRawValue(HKEY_CURRENT_USER, cmd_subkey, nullptr,
                                &state.previous_command) ||
          !ReadRegistryRawValue(HKEY_CURRENT_USER, cmd_subkey,
                                L"DelegateExecute",
                                &state.previous_delegate_execute)) {
        if (error_out != nullptr) {
          *error_out =
              "Failed to snapshot existing HKCU custom-scheme settings.";
        }
        return false;
      }
    }
  }

  HKEY scheme_key = nullptr;
  DWORD disposition = 0;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, scheme_subkey.c_str(), 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                        &scheme_key, &disposition) != ERROR_SUCCESS) {
    if (error_out != nullptr) {
      *error_out = "Failed to open HKCU registry key for custom scheme.";
    }
    return false;
  }

  if (disposition == REG_CREATED_NEW_KEY) {
    state.created_by_savedex = true;
  }

  bool write_ok = true;
  if (state.created_by_savedex) {
    write_ok =
        WriteRegistryStringValue(scheme_key, nullptr, REG_SZ,
                                 kSavedexProtocolDescription) &&
        WriteRegistryStringValue(scheme_key, L"URL Protocol", REG_SZ, L"") &&
        WriteRegistryStringValue(scheme_key, kSavedexOwnedMarkerValue, REG_SZ,
                                 L"1");
  } else {
    if (!state.previous_default.existed) {
      write_ok = WriteRegistryStringValue(scheme_key, nullptr, REG_SZ,
                                          kSavedexProtocolDescription);
    }
    if (write_ok) {
      write_ok =
          WriteRegistryStringValue(scheme_key, L"URL Protocol", REG_SZ, L"");
    }
  }
  ::RegCloseKey(scheme_key);

  if (write_ok) {
    HKEY cmd_key = nullptr;
    if (::RegCreateKeyExW(HKEY_CURRENT_USER, cmd_subkey.c_str(), 0, nullptr,
                          REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &cmd_key,
                          nullptr) == ERROR_SUCCESS) {
      const std::wstring command_value = L"\"" + exe_path + L"\" \"%1\"";
      write_ok = WriteRegistryStringValue(cmd_key, nullptr, REG_SZ,
                                          command_value);
      if (write_ok && state.previous_delegate_execute.existed) {
        const LSTATUS del_status =
            ::RegDeleteValueW(cmd_key, L"DelegateExecute");
        write_ok = (del_status == ERROR_SUCCESS ||
                    del_status == ERROR_FILE_NOT_FOUND);
      }
      ::RegCloseKey(cmd_key);
    } else {
      write_ok = false;
    }
  }

  saved_registry_ = std::move(state);
  if (!write_ok) {
    RestoreRegisteredScheme();
    if (error_out != nullptr) {
      *error_out = "Failed to register custom scheme command in HKCU.";
    }
    return false;
  }

  return true;
}

void RedditAuthHandler::RestoreRegisteredScheme() {
  if (!saved_registry_.has_value()) {
    return;
  }

  const SavedRegistryState state = std::move(*saved_registry_);
  saved_registry_.reset();

  const std::wstring scheme_subkey = L"Software\\Classes\\" + state.scheme;
  if (state.created_by_savedex) {
    ::RegDeleteTreeW(HKEY_CURRENT_USER, scheme_subkey.c_str());
    return;
  }

  HKEY scheme_key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, scheme_subkey.c_str(), 0, KEY_WRITE,
                      &scheme_key) == ERROR_SUCCESS) {
    if (state.previous_default.existed) {
      WriteRegistryRawValue(scheme_key, nullptr, state.previous_default);
    } else {
      ::RegDeleteValueW(scheme_key, nullptr);
    }

    if (state.previous_url_protocol.existed) {
      WriteRegistryRawValue(scheme_key, L"URL Protocol",
                            state.previous_url_protocol);
    } else {
      ::RegDeleteValueW(scheme_key, L"URL Protocol");
    }
    ::RegCloseKey(scheme_key);
  }

  const std::wstring shell_subkey = scheme_subkey + L"\\shell";
  const std::wstring open_subkey = shell_subkey + L"\\open";
  const std::wstring cmd_subkey = open_subkey + L"\\command";

  if (state.previous_command.existed || state.previous_delegate_execute.existed) {
    HKEY cmd_key = nullptr;
    if (::RegCreateKeyExW(HKEY_CURRENT_USER, cmd_subkey.c_str(), 0, nullptr,
                          REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &cmd_key,
                          nullptr) == ERROR_SUCCESS) {
      if (state.previous_command.existed) {
        WriteRegistryRawValue(cmd_key, nullptr, state.previous_command);
      } else {
        ::RegDeleteValueW(cmd_key, nullptr);
      }
      if (state.previous_delegate_execute.existed) {
        WriteRegistryRawValue(cmd_key, L"DelegateExecute",
                              state.previous_delegate_execute);
      }
      ::RegCloseKey(cmd_key);
    }
  } else if (!state.shell_key_existed) {
    ::RegDeleteTreeW(HKEY_CURRENT_USER, shell_subkey.c_str());
  } else if (!state.open_key_existed) {
    ::RegDeleteTreeW(HKEY_CURRENT_USER, open_subkey.c_str());
  } else if (!state.command_key_existed) {
    ::RegDeleteTreeW(HKEY_CURRENT_USER, cmd_subkey.c_str());
  } else {
    HKEY cmd_key = nullptr;
    if (::RegOpenKeyExW(HKEY_CURRENT_USER, cmd_subkey.c_str(), 0, KEY_WRITE,
                        &cmd_key) == ERROR_SUCCESS) {
      ::RegDeleteValueW(cmd_key, nullptr);
      ::RegCloseKey(cmd_key);
    }
  }
}
