# Based on Nim's uri.nim
# (c) Copyright 2015 Dominik Picheta
import strutils, parseutils
import uri
export Uri

proc parseAuthority(authority: string, result: var Uri) =
  var i = 0
  var inPort = false
  while true:
    case authority[i]
    of '@':
      swap result.password, result.port
      result.port.setLen(0)
      swap result.username, result.hostname
      result.hostname.setLen(0)
      inPort = false
    of ':':
      inPort = true
    of '\0': break
    else:
      if inPort:
        result.port.add(authority[i])
      else:
        result.hostname.add(authority[i])
    i.inc

proc parsePath(uri: string, i: var int, result: var Uri) =
  i.inc parseUntil(uri, result.path, {'?', '#'}, i)

  # The 'mailto' scheme's PATH actually contains the hostname/username
  if result.scheme.toLower == "mailto":
    parseAuthority(result.path, result)
    result.path.setLen(0)

  if uri[i] == '?':
    i.inc # Skip '?'
    i.inc parseUntil(uri, result.query, {'#'}, i)

  if uri[i] == '#':
    i.inc # Skip '#'
    i.inc parseUntil(uri, result.anchor, {}, i)

proc parseUri(uri: string, result: var Uri) =
  var i = 0

  # Check if this is a reference URI (relative URI)
  let doubleSlash = uri.len > 1 and uri[1] == '/'
  if uri[i] == '/':
    # Make sure ``uri`` doesn't begin with '//'.
    if not doubleSlash:
      parsePath(uri, i, result)
      return

  # Scheme
  i.inc parseWhile(uri, result.scheme, Letters + Digits + {'+', '-', '.'}, i)
  if uri[i] != ':' and not doubleSlash:
    # Assume this is a reference URI (relative URI)
    i = 0
    result.scheme.setLen(0)
    parsePath(uri, i, result)
    return
  if not doubleSlash:
    i.inc # Skip ':'

  # Authority
  if uri[i] == '/' and uri[i+1] == '/':
    i.inc(2) # Skip //
    var authority = ""
    i.inc parseUntil(uri, authority, {'/', '?', '#'}, i)
    parseAuthority(authority, result)
  else:
    result.opaque = true

  # Path
  parsePath(uri, i, result)

proc parseUri*(uri: string): Uri =
  ## Parses a URI and returns it.
  result = initUri()
  parseUri(uri, result)
