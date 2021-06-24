import servers/[socketserver, httpserver]
import clients/[socketclient, httpclient]

type RpcHttpProxy* = ref object of RootRef
    rpcHttpClient: RpcHttpClient
    rpcHttpServer: RpcHttpServer

proc proxyCall(client: RpcHttpClient): RecoveryProc =
  result = 
    proc (name: string, params: JsonNode): Future[Response] = client.call(name, params)

proc new*(T: type RpcHttpProxy, listenAddresses: openArray[string]): T = 
    let client = newRpcHttpClient()
    let proxyCall = proxyCall(client)
    let router = RpcRouter.init(proxyCall)
    T(rpcHttpClient: client, rpcHttpServer: newRpcHttpServer(listenAddresses, router))

proc newRpcHttpProxy*(listenAddresses: openArray[string]): RpcHttpProxy =
    RpcHttpProxy.new(listenAddresses)

proc init*(proxy:RpcHttpProxy, proxyServerUrl: string) {.async.} =
    proxy.rpcHttpServer.start()
    await proxy.rpcHttpClient.connect(proxyServerUrl)

proc init*(proxy:RpcHttpProxy, proxyServerAddress: string, proxyServerPort: Port) {.async.} =
    proxy.rpcHttpServer.start()
    await proxy.rpcHttpClient.connect(proxyServerAddress, proxyServerPort)

template rpc*(server: RpcHttpProxy, path: string, body: untyped): untyped =
  server.rpcHttpServer.rpc(path, body)

proc stop*(rpcHttpProxy: RpcHttpProxy) =
    rpcHttpProxy.rpcHttpServer.stop()

proc closeWait*(rpcHttpProxy: RpcHttpProxy) {.async.} =
    await rpcHttpProxy.rpcHttpServer.closeWait()