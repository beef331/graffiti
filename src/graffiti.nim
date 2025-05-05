import std/[osproc, strutils, os, sequtils, algorithm, sets, strscans, strformat, options]
import experimental/cmdline


const 
  gitCommand = "git -C $1 log --format=\"%H %s\" -- $2"
  diffCommand = "git -C $1 diff $2~ $2 $3"
  tagCommand = "git -C $1 tag -a v$2 $3 -m \"$4\""
  pushCommand = "git -C $1 push --tags"
  tagListCommand = "git -C $1 tag"


type Parameters = object
  nimblePath: string
  tagVersion: Option[string]

var cli = Parameters.commandBuilder()
  .name("graffiti")
  .describe("Does the redundant and tags a nimble file and makes a git tag cause Nimble files are forced to have a version.")
  .initCli()

cli.positionalBuilder
  .name("Nimble file")
  .parser(string, proc(value: string, params: var Parameters): Action =
    params.nimblePath = value
  )
  .describe("The Nimble path for the library you want to tag.")
  .addTo(cli)

cli.positionalBuilder
  .name("Version")
  .optional()
  .describe("If provided writes this value into the nimble file. Makes a new git tag then pushes. Must be in Major.Minor.Patch form.")
  .parser(string, (proc(value: string, params: var Parameters): Action =
    if value.scantuple("$i.$i.$i")[0]:
      params.tagVersion = some(value) 
      Continue
    else:
      echo "Incorrect new version number"
      ShowHelp
  )
  ).addTo(cli)

let conf = cli.run()

if conf.tagVersion.isSome():
  let 
    newVersion = conf.tagVersion.get
    nimble = readFile(conf.nimblePath)
    theFile = open(conf.nimblePath, fmWrite)

  for line in nimble.splitLines:
    if line.scanTuple("version$s=")[0]:
      theFile.writeLine "version = \"", newVersion, "\""
    else:
      theFile.writeLine(line)
  theFile.close()
  discard execShellCmd(fmt"git add {conf.nimblePath}")
  discard execShellCmd(fmt"""git commit -m "Bump Nimble to {newVersion}"""")
  discard execShellCmd("git push")


let
  parent = conf.nimblePath.parentDir()
  nimbleFile = conf.nimblePath.splitPath.tail
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


