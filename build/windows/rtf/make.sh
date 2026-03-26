#!/usr/bin/env bash
# Creates the RTF license file required by the Windows InnoSetup installer.
# Runs from within the vscode/ directory.

set -e

mkdir -p resources/win32

# Convert LICENSE.txt to minimal RTF for InnoSetup
awk 'BEGIN {
    print "{\\rtf1\\ansi\\ansicpg1252\\deff0"
    print "{\\fonttbl{\\f0\\fmodern\\fcharset0 Courier New;}}"
    print "\\widowctrl\\wpaper12240\\wpaperh15840\\margl1800\\margr1800\\margt1440\\margb1440"
    print "\\f0\\fs18"
}
{
    gsub(/\\/, "\\\\")
    gsub(/{/, "\\{")
    gsub(/}/, "\\}")
    print $0 "\\par"
}
END {
    print "}"
}' LICENSE.txt > resources/win32/code_license.rtf

echo "Created resources/win32/code_license.rtf"
