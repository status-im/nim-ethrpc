#[
  This module uses debug versions of the rpc components that
  allow unchecked and unformatted calls.
]#

import unittest, debugclient, ../rpcserver
import strformat, chronicles

var server = newRpcServer("localhost", 8547.Port)
var client = newRpcClient()

server.start()
waitFor client.connect("localhost", Port(8547))

server.rpc("rpc") do(a: int, b: int):
  result = %(&"a: {a}, b: {b}")

proc testMissingRpc: Future[Response] {.async.} =
  var fut = client.call("phantomRpc", %[])
  result = await fut

proc testMalformed: Future[Response] {.async.} =
  let malformedJson = "{field: 2, \"field: 3}"
  var fut = client.rawCall("rpc", malformedJson)
  await fut or sleepAsync(10000)
  if fut.finished: result = fut.read()

proc testInvalidJsonVer: Future[Response] {.async.} =
  let json =
    $ %{"jsonrpc": %"3.99", "method": %"rpc", "params": %[],
      "id": % $client.nextId} & "\c\l"
  var fut = client.rawCall("rpc", json)
  result = await fut

suite "RPC Errors":
  test "Missing RPC":
    let res = waitFor testMissingRpc()
    echo res
    check res.error == true and
      res.result["message"] == %"Method not found" and
      res.result["data"] == %"phantomRpc is not a registered method."

  test "Incorrect json version":
    # Note: We don't expect an exception here, because the server should
    # respond with the correct json version
    let res = waitFor testInvalidJsonVer()
    check res.error == true and res.result["message"] == %"JSON 2.0 required"

  # TODO: Missing ID causes client await to not return next call
  # For now we can use curl for this test
  #[test "Malformed json":
    expect ValueError:
      let res = waitFor testMalformed()
      echo res
  ]#
