import std/[osproc, strutils, os, sequtils, algorithm, sets, strscans, strformat]

const 
  gitCommand = "git -C $1 log --format=oneline -- $2"
  diffCommand = "git -C $1 diff $2~ $2 $3"
  tagCommand = "git -C $1 tag -a v$2 $3 -m \"$4\""
  pushCommand = "git -C $1 push --tags"
  tagListCommand = "git -C $1 tag"

assert paramCount() == 1

let
  path = paramStr(1)
  parent = path.parentDir()
  nimbleFile = path.splitPath.tail
  commits = execCmdEx(gitCommand % [parent, nimbleFile])

var versions: HashSet[string]

for line in execCmdEx(tagListCommand % parent).output.splitLines:
  if line.startsWith("v"):
    versions.incl line[1..^1].strip()

proc getCommitMessage(line: string): string =
  result = "\""
  let messageStart = line.find " "
  result.add:
    if messageStart > 0:
      quoteShell(line[messageStart + 1 .. ^1])
    else:
      "Automated Git Tag"
  result.add "\""

let startSize = versions.len

for line in commits.output.splitLines:
  var commit: string
  if line.scanF("$+ ", commit):
    let message = getCommitMessage(line)
    let diff = execCmdEx(diffCommand % [parent, commit, nimbleFile])
    for line in diff.output.splitLines:
      var version: string
      if line.startswith("+version"):
        let start = line.rFind("=")
        if line[start+1..^1].scanf("$s\"$+\"", version) and version notin versions:
          discard execShellCmd(tagCommand % [parent, version, commit, message])
          echo "Created Version: ", version, ", with message: ", message
          versions.incl version

if startSize != versions.len:
  echo fmt"Created new tags for {versions.len - startSize} versions. Pushing now"
  discard execShellCmd(pushCommand % parent)
else:
  echo "No new versions found."


