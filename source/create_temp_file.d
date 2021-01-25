/*
A fork of std.file that includes a createTempFile function.
ripped from:
https://github.com/dlang/phobos/pull/5788/commits/a4b45bbc46f487e0e1a175fcbe2134e826f098b9
*/

/**
Copyright: Copyright Digital Mars 2007 - 2011.
See_Also:  The $(HTTP ddili.org/ders/d.en/files.html, official tutorial) for an
introduction to working with files in D, module
$(MREF std, stdio) for opening files and manipulating them via handles,
and module $(MREF std, path) for manipulating path strings.

License:   $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(HTTP digitalmars.com, Walter Bright),
           $(HTTP erdani.org, Andrei Alexandrescu),
           $(HTTP jmdavisprog.com, Jonathan M Davis)
Source:    $(PHOBOSSRC std/_file.d)
 */

public import std.file;


import core.stdc.errno, core.stdc.stdlib, core.stdc.string;
import core.time : abs, dur, hnsecs, seconds;

import std.datetime.date : DateTime;
import std.datetime.systime : Clock, SysTime, unixTimeToStdTime;
import std.internal.cstring;
import std.meta;
import std.range.primitives;
import std.traits;
import std.typecons;

version (Windows)
{
    import core.sys.windows.windows, std.windows.syserror;
}
else version (Posix)
{
    import core.sys.posix.dirent, core.sys.posix.fcntl, core.sys.posix.sys.stat,
        core.sys.posix.sys.time, core.sys.posix.unistd, core.sys.posix.utime;
}
else
    static assert(false, "Module " ~ .stringof ~ " not implemented for this OS.");

// Character type used for operating system filesystem APIs
version (Windows)
{
    private alias FSChar = wchar;
}
else version (Posix)
{
    private alias FSChar = char;
}
else
    static assert(0);


private T cenforce(T)(T condition, lazy const(char)[] name, string file = __FILE__, size_t line = __LINE__)
{
    if (condition)
        return condition;
    version (Windows)
    {
        throw new FileException(name, .GetLastError(), file, line);
    }
    else version (Posix)
    {
        throw new FileException(name, .errno, file, line);
    }
}

version (Windows)
@trusted
private T cenforce(T)(T condition, const(char)[] name, const(FSChar)* namez,
    string file = __FILE__, size_t line = __LINE__)
{
    if (condition)
        return condition;
    if (!name)
    {
        import core.stdc.wchar_ : wcslen;
        import std.conv : to;

        auto len = namez ? wcslen(namez) : 0;
        name = to!string(namez[0 .. len]);
    }
    throw new FileException(name, .GetLastError(), file, line);
}

version (Posix)
@trusted
private T cenforce(T)(T condition, const(char)[] name, const(FSChar)* namez,
    string file = __FILE__, size_t line = __LINE__)
{
    if (condition)
        return condition;
    if (!name)
    {
        import core.stdc.string : strlen;

        auto len = namez ? strlen(namez) : 0;
        name = namez[0 .. len].idup;
    }
    throw new FileException(name, .errno, file, line);
}

private void writeToOpenFile(FD)(FD fd, const void[] buffer, const(char)[] name,
                                 const(FSChar)* namez) @trusted
{
    immutable size = buffer.length;
    size_t sum, cnt = void;

    while (sum != size)
    {
        cnt = size - sum < 2^^30 ? size - sum : 2^^30;

        version(Posix)
            immutable numWritten = core.sys.posix.unistd.write(fd, buffer.ptr + sum, cnt);
        else version(Windows)
        {
            DWORD numWritten = void;
            WriteFile(fd, buffer.ptr + sum, cast(uint) cnt, &numWritten, null);
        }
        else
            static assert(0, "Unsupported OS");

        if (numWritten != cnt)
            break;
        sum += numWritten;
    }

    version(Posix)
        cenforce(sum == size && core.sys.posix.unistd.close(fd) == 0, name, namez);
    else version(Windows)
        cenforce(sum == size && CloseHandle(fd), name, namez);
    else
        static assert(0, "Unsupported OS");
}

string createTempFile(const void[] buffer = null) @safe
{
    return createTempFile(null, null, buffer);
}

/// Ditto
string createTempFile(const(char)[] prefix, const(char)[] suffix, const void[] buffer = null) @trusted
{
    import std.path : absolutePath, baseName, buildPath, dirName;

    static string genTempName(const(char)[] prefix, const(char)[] suffix)
    {
        import std.ascii : digits, letters;
        import std.random : choice, rndGen;
        import std.range : chain;
        import std.string : representation;

        auto name = new char[](prefix.length + 15 + suffix.length);
        name[0 .. prefix.length] = prefix;
        name[$ - suffix.length .. $] = suffix;

        auto random = &rndGen();
        rndGen.popFront();

        auto chars = chain(letters.representation, digits.representation);
        foreach (ref c; name[prefix.length .. $ - suffix.length])
        {
            c = choice(chars);
            random.popFront();
        }

        return buildPath(tempDir, name);
    }

    while (1)
    {
        auto filename = genTempName(prefix, suffix);

        version(Posix)
        {
            auto fd = open(tempCString!FSChar(filename), O_RDWR | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR);
            if (fd == -1)
            {
                immutable errno = .errno;
                if (errno == EEXIST)
                    continue;
                else
                    throw new FileException("Failed to create a temporary file", errno);
            }
        }
        else version(Windows)
        {
            auto fd = CreateFileW(tempCString!FSChar(filename), GENERIC_WRITE, 0, null, CREATE_NEW,
                                  FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, HANDLE.init);
            if (fd == INVALID_HANDLE_VALUE)
            {
                immutable errno = .GetLastError();
                if (errno == ERROR_FILE_EXISTS)
                    continue;
                else
                    throw new FileException("Failed to create a temporary file", errno);
            }
        }
        else
            static assert(0, "Unsupported OS");

        writeToOpenFile(fd, buffer, filename, null);

        return filename;
    }
}
