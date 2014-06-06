A brain-dead effectful streaming library, just to see how much we can get away
with, using as little as possible.  I.e., the one-legged centipede version of
conduit. :-)

Features conspicuously lacking:

    - Conduits are not Monads, which omits a lot of important use cases
    - No leftovers

Features surprisingly present:

    - Performance within 20% of conduit in simple cases
    - Early termination by consumers
    - Notification of uptream termination
    - Not a continuation, so monad-control can be used for resource control
    - Prompt finalization
    - Sources are Monoids (though making it an instance takes more work)

What's interesting is that this library is simply a convenience for chaining
monadic folds, and nothing more.  I find it interesting how much of conduit
can be expressed using only that abstraction.
