# The commands that Expect adds to Tcl, for the language server (tcl-ls), which knows only Tcl's.
#
# Every script of the repository runs under expect (check/test, the tests of the profiles, the
# scripts of the qemu-image-testing skill), so tcllsrc.tcl activates the module for all of them.
#
# Most commands take flags that vary by use, so their shape is `args`: the server then knows the
# name and not the arguments. The bodies of `expect` and `interact` are lists of pattern and action
# pairs, which the server cannot analyse, so the variables that their actions use look unused.
meta module Expect {
    # Expect's `close` and `exit` take flags (`close -i $spawn_id`, `exit -onexit proc`) that Tcl's
    # do not.
    meta override close {args}
    meta override exit {args}

    meta command disconnect {args}
    meta command exp_continue {args}
    meta command exp_internal {args}
    meta command exp_open {args}
    meta command exp_pid {args}
    meta command exp_send {args}
    meta command exp_send_error {args}
    meta command exp_send_log {args}
    meta command exp_send_tty {args}
    meta command exp_send_user {args}
    meta command exp_version {args}
    meta command expect {args}
    meta command expect_after {args}
    meta command expect_background {args}
    meta command expect_before {args}
    meta command expect_tty {args}
    meta command expect_user {args}
    meta command fork {args}
    meta command inter_return {args}
    meta command interact {args}
    meta command interpreter {args}
    meta command log_file {args}
    meta command log_user {args}
    meta command match_max {args}
    meta command overlay {args}
    meta command parity {args}
    meta command remove_nulls {args}
    meta command send {args}
    meta command send_error {args}
    meta command send_log {args}
    meta command send_tty {args}
    meta command send_user {args}
    meta command sleep {seconds}
    meta command spawn {args}
    meta command strace {args}
    meta command stty {args}
    meta command system {args}
    meta command timestamp {args}
    meta command trap {args}
    meta command wait {args}
}
