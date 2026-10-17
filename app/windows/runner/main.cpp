#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Only one copy of the app runs at a time: two would share one core and one control file. A second
// start hands what it was started with (a link or a file to open) to the running copy, brings that
// window forward and ends.
constexpr wchar_t kSingleInstanceMutex[] = L"Local\\Wardkeep.SingleInstance";

bool HandOverToRunningCopy(const std::vector<std::string>& arguments) {
  HWND existing = nullptr;
  // The first copy may still be opening its window.
  for (int i = 0; i < 50 && !existing; i++) {
    // Every Flutter app on Windows has this window class, so the title names ours.
    existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Wardkeep");
    if (!existing) ::Sleep(100);
  }
  if (!existing) return false;
  std::string joined;
  for (const auto& a : arguments) {
    if (!joined.empty()) joined += '\n';
    joined += a;
  }
  if (!joined.empty()) {
    COPYDATASTRUCT data;
    data.dwData = kHandOverTag;
    data.cbData = static_cast<DWORD>(joined.size());
    data.lpData = const_cast<char*>(joined.data());
    ::SendMessageW(existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data));
  }
  if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
  ::SetForegroundWindow(existing);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Kept for the life of the process: the system releases it when the process ends.
  HANDLE single_instance = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (single_instance != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (HandOverToRunningCopy(command_line_arguments)) return EXIT_SUCCESS;
    // No window to hand over to (the other copy is stuck or closing): carry on as a new copy.
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(520, 720);
  if (!window.Create(L"Wardkeep", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
