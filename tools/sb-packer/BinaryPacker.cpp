#include <Windows.h>
#include <fcntl.h>
#include <io.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

using namespace std;
namespace fs = std::filesystem;

namespace
{
    constexpr DWORD CopyBufferSize = 1024 * 1024;

    void Require(BOOL success, const wchar_t* operation)
    {
        if (!success)
        {
            const DWORD error = GetLastError();
            throw wstring(operation) + L" 실패 (Windows 오류 " + to_wstring(error) + L")";
        }
    }

    uint64_t SizeOf(const BY_HANDLE_FILE_INFORMATION& info)
    {
        return (uint64_t{info.nFileSizeHigh} << 32) | info.nFileSizeLow;
    }

    void WriteAll(HANDLE file, const void* data, DWORD size)
    {
        auto cursor = static_cast<const char*>(data);
        while (size > 0)
        {
            DWORD written = 0;
            Require(WriteFile(file, cursor, size, &written, nullptr), L"결과 기록");
            if (written == 0)
                throw wstring(L"결과에 데이터를 기록하지 못했습니다.");
            cursor += written;
            size -= written;
        }
    }

    // 구조체 메모리를 그대로 쓰지 않고 SB v1의 little endian 순서를 직접 기록한다.
    void PutInteger(array<unsigned char, 16>& header, size_t offset, uint64_t value, size_t count)
    {
        for (size_t index = 0; index < count; ++index)
            header[offset + index] = static_cast<unsigned char>(value >> (index * 8));
    }

    fs::path Pack(const fs::path& input)
    {
        const fs::path source = fs::absolute(input);
        const string filename = source.filename().u8string();
        if (filename.size() > UINT16_MAX)
            throw wstring(L"UTF-8 파일명이 SB 형식의 길이 제한을 초과했습니다.");

        // 쓰기/삭제 공유를 허용하지 않아 처리 중 원본 수정을 막는다.
        HANDLE reader = CreateFileW(source.c_str(), GENERIC_READ, FILE_SHARE_READ,
            nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
        Require(reader != INVALID_HANDLE_VALUE, L"원본 열기");
        HANDLE writer = INVALID_HANDLE_VALUE;
        fs::path output;
        try
        {
            BY_HANDLE_FILE_INFORMATION before{};
            Require(GetFileInformationByHandle(reader, &before), L"원본 정보 조회");
            if (GetFileType(reader) != FILE_TYPE_DISK || (before.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
                throw wstring(L"일반 파일만 처리할 수 있습니다.");

            // CREATE_NEW로 기존 결과를 덮어쓰지 않는다. 충돌하면 번호를 붙인다.
            for (uint64_t index = 0; ; ++index)
            {
                const wstring suffix = index == 0 ? L"" : L" (" + to_wstring(index) + L")";
                output = source.parent_path() / (source.filename().wstring() + suffix + L".sb");
                writer = CreateFileW(output.c_str(), GENERIC_WRITE | DELETE, 0,
                    nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
                if (writer != INVALID_HANDLE_VALUE)
                    break;
                const DWORD error = GetLastError();
                if (error != ERROR_FILE_EXISTS && error != ERROR_ALREADY_EXISTS)
                    Require(FALSE, L"결과 생성");
            }

            const uint64_t size = SizeOf(before);
            array<unsigned char, 16> header{ 'S', 'B', 'I', 'N' };
            PutInteger(header, 4, 1, 2);
            PutInteger(header, 6, filename.size(), 2);
            PutInteger(header, 8, size, 8);
            WriteAll(writer, header.data(), static_cast<DWORD>(header.size()));
            WriteAll(writer, filename.data(), static_cast<DWORD>(filename.size()));

            vector<char> buffer(CopyBufferSize);
            uint64_t remaining = size;
            while (remaining > 0)
            {
                DWORD read = 0;
                const DWORD requested = static_cast<DWORD>(min<uint64_t>(remaining, buffer.size()));
                Require(ReadFile(reader, buffer.data(), requested, &read, nullptr), L"원본 읽기");
                if (read == 0)
                    throw wstring(L"처리 중 원본 크기가 변경됐습니다.");
                WriteAll(writer, buffer.data(), read);
                remaining -= read;
            }
            BY_HANDLE_FILE_INFORMATION after{};
            Require(GetFileInformationByHandle(reader, &after), L"원본 재확인");
            if (SizeOf(after) != size || CompareFileTime(&before.ftLastWriteTime, &after.ftLastWriteTime) != 0)
                throw wstring(L"처리 중 원본이 변경됐습니다.");
            Require(FlushFileBuffers(writer), L"결과 저장");
        }
        catch (...)
        {
            if (writer != INVALID_HANDLE_VALUE)
            {
                // 열린 결과 핸들에 삭제를 예약한 뒤 닫아 이번 불완전한 파일만 지운다.
                FILE_DISPOSITION_INFO discard{ TRUE };
                const BOOL removed = SetFileInformationByHandle(writer, FileDispositionInfo, &discard, sizeof(discard));
                CloseHandle(writer);
                if (!removed && !DeleteFileW(output.c_str()))
                    wcerr << L"[정리 실패] " << output.wstring() << L'\n';
            }
            CloseHandle(reader);
            throw;
        }
        CloseHandle(writer);
        CloseHandle(reader);
        return output;
    }
}

int wmain(int argc, wchar_t* argv[])
{
    // 콘솔은 UTF-16, 로그 리디렉션은 UTF-8로 출력한다.
    (void)_setmode(_fileno(stdout), _isatty(_fileno(stdout)) ? _O_U16TEXT : _O_U8TEXT);
    (void)_setmode(_fileno(stderr), _isatty(_fileno(stderr)) ? _O_U16TEXT : _O_U8TEXT);
    if (argc == 1)
        wcout << L"Binary Packer\n파일을 BinaryPacker.exe 위에 드롭하세요.\n"
            L"사용법: BinaryPacker.exe 파일경로 [파일경로 ...]\n"
            L"원본과 같은 폴더에 .sb 파일을 만듭니다.\n";

    int failures = 0;
    for (int index = 1; index < argc; ++index)
    {
        try
        {
            const fs::path output = Pack(argv[index]);
            wcout << L"[완료] " << output.wstring() << L'\n';
        }
        catch (const wstring& message)
        {
            ++failures;
            wcerr << L"[실패] " << argv[index] << L": " << message << L'\n';
        }
        catch (const exception&)
        {
            ++failures;
            wcerr << L"[실패] " << argv[index] << L": 경로 변환 또는 메모리 할당에 실패했습니다.\n";
        }
    }
    if (argc > 1)
        wcout << L"완료 " << argc - 1 - failures << L"개 / 실패 " << failures << L"개\n";

    // 탐색기에서 새로 열린 콘솔만 유지한다. 명령줄 호출은 바로 반환한다.
    DWORD consoleProcesses[2]{};
    if (_isatty(_fileno(stdin)) && _isatty(_fileno(stdout)) && GetConsoleProcessList(consoleProcesses, 2) == 1)
    {
        wcout << L"Enter 키를 누르면 종료합니다." << flush;
        wstring line;
        getline(wcin, line);
    }
    return failures == 0 ? 0 : 1;
}
