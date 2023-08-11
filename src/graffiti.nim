import std/[osproc, strutils, os, sequtils, algorithm, sets, strscans, strformat]

const 
  gitCommand = "git -C $1 log --format=\"%H %s\" -- $2"
  diffCommand = "git -C $1 diff $2~ $2 $3"
  tagCommand = "git -C $1 tag -a v$2 $3 -m \"$4\""
  pushCommand = "git -C $1 push --tags"
  tagListCommand = "git -C $1 tag"

assert paramCount() in [1, 2]

let
  path = paramStr(1)

if paramCount() == 2:
  let newVersion = paramStr(2)
  if not newVersion.scantuple("$i.$i.$i")[0]:
    raiseAssert("Incorrect new version number")
  let 
    nimble = readFile(path)
    theFile = open(path, fmWrite)

  for line in nimble.splitLines:
    if line.scanTuple("version$s=")[0]:
      theFile.writeLine "version = \"", newVersion, "\""
    else:
      theFile.writeLine(line)
  theFile.close()
  discard execShellCmd(fmt"git add {path}")
  discard execShellCmd(fmt"""git commit -m "Bump Nimble to {newVersion}"""")
  discard execShellCmd("git push")

let
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

for commitLine in commits.output.splitLines:
  var commit: string
  if commitLine.scanF("$+ ", commit):
    let diff = execCmdEx(diffCommand % [parent, commit, nimbleFile])
    for line in diff.output.splitLines:
      var version: string
      if line.startswith("+version"):
        let start = line.rFind("=")
        if line[start+1..^1].scanf("$s\"$+\"", version) and version notin versions:
          let message = getCommitMessage(commitLine)
          discard execShellCmd(tagCommand % [parent, version, commit, message])
          echo "Created Version: ", version, ", with message: ", message[1..^2]
          versions.incl version

if startSize != versions.len:
  echo fmt"Created new tags for {versions.len - startSize} versions. Pushing now"
  discard execShellCmd(pushCommand % parent)
else:
  echo "No new versions found."


