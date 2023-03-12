import std/[osproc, strutils, os, sequtils, algorithm, sets, strscans]

const 
  gitCommand = "git -C $1 log --format=oneline -- $2"
  diffCommand = "git -C $1 diff $2~ $2 $3"
  tagCommand = "git -C $1 tag -a v$2 $3 -m \"$4\""
  pushCommand = "git -C $1 push origin v$2"
  tagListCommand = "git -C $1 tag"

assert paramCount() == 1

let
  path = paramStr(1)
  parent = path.parentDir()
  nimbleFile = path.splitPath.tail
  commits = execCmdEx(gitCommand % [parent, nimbleFile], options = {poEchoCmd})

var versions: HashSet[string]

for line in execCmdEx(tagListCommand % parent).output.splitLines:
  if line.startsWith("v"):
    versions.incl line[1..^1].strip()

for line in commits.output.splitLines:
  var commit: string
  if line.scanF("$+ ", commit):
    let
      messageStart = line.find " "
      message =
        if messageStart > 0:
          quoteShell(line[messageStart + 1 .. ^1])
        else:
          "Automated Git Tag"
    let diff = execCmdEx(diffCommand % [parent, commit, nimbleFile])
    for line in diff.output.splitLines:
      var version: string
      if line.startswith("+version"):
        let start = line.rFind("=")
        if line[start+1..^1].scanf("$s\"$+\"", version) and version notin versions:
          discard execShellCmd(tagCommand % [parent, version, commit, message])
          discard execShellCmd(pushCommand % [parent, version])
          versions.incl version


