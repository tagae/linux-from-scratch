# The configuration of the Tcl language server (tcl-ls) for the whole repository.

# Every script runs under expect.
source .tcl-ls/expect.meta.tcl
module Expect

# The tests of the profiles call the procedures that check/test defines.
meta source check/test
