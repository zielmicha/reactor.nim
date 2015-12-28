include reactor/async/future
export Future, Completer, getFuture, newCompleter, then, onSuccessOrError

include reactor/async/stream
export Stream, Provider, provide, provideSome, provideAll, peekMany, discardItems, receive, receiveMany
