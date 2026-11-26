Git Commit Message Conventions
==============================

Start with a summary line
-------------------------

Begin the message with a short summary line a.k.a. subject, in the form of a semantic commit:

    <type>: <subject>

  * Start with one of the types below: a type is a word of its own, and `feat!` is as much a type as
    `feat`. There are no scopes, as in `feat(virt):`.
  * Start the subject with an imperative present active verb, in lowercase: add, drop, fix, etc.
  * Use up to 72 characters for the whole line, so that the log and the web show it uncut.
  * Finish without a sentence-ending period.
  * Put no other meta-information in it, such as `[bug]`, `(release)`, `#12345` or a ticket ID
    (`JIRA-666`): pass a ticket ID as a trailer instead (`Issue: 25`).

Right and wrong:

  * Right: feat: add feature
  * Wrong: feat: Add feature (the subject starts with an uppercase letter)
  * Wrong: feat: add feature. (a sentence-ending period)
  * Right: feat: add feature for U.S.A. (the period ends an abbreviation)
  * Wrong: feat: adds feature (indicative mood, not imperative)
  * Wrong: feat: added feature (past tense, not present)
  * Wrong: feat: adding feature (the lead is a gerund, not a verb)
  * Wrong: feat: feature added (passive voice, not active)


Continue with a longer description
----------------------------------

Continue with a longer description a.k.a. message body:

  * Add a blank line after the summary line, as Git's tools expect (the convention of an email).
  * Use up to 72 characters per line for typical text, for easy reading on terminals.
  * Use as many characters as needed for atypical text, such as URLs, terminal output or formatted
    messages, to preserve its formatting.
  * Use Markdown: links for external references, e.g. [text](https://example.com), code blocks for
    terminal output and formatted messages, lists to enumerate changes and notes, and headings for
    long messages with several topics.

Example:

    fix: parse the input of foo

    The fix changes how we parse the input. See [the issue](https://example.com/25)
    for details.


Summary examples
----------------

  * feat: add foo
  * drop: remove foo
  * fix: stop foo from hanging
  * upgrade: bump foo to 2.0
  * refactor: move foo to lib/foo.sh
  * perf: build foo once for all platforms
  * feat!: prefix the variables of foo with FOO_
  * drop!: remove the foo command
  * drop: remove the unused foo option


Types
-----

The type is one of these:

| Type       | Use it for                                                                         |
|------------|------------------------------------------------------------------------------------|
| `feat`     | Create a capability e.g. a package, profile, option, command or file of an image.  |
| `feat!`    | Change a capability that users rely on, in a way that breaks them.                 |
| `fix`      | Fix an issue e.g. bug, typo, accident, misstatement, or vulnerability.             |
| `upgrade`  | Upgrade a package or tool, whether or not the new release fixes a vulnerability.   |
| `perf`     | A change that MUST be just about performance, e.g. build faster or ship less.      |
| `refactor` | A change that MUST be just a refactoring: it changes nothing that users can see.   |
| `drop`     | Delete a capability that nothing relies on e.g. feature, option, package, command. |
| `drop!`    | Delete a capability that users rely on.                                            |
| `docs`     | A change that MUST be only in the documentation or in comments.                    |
| `style`    | A change that MUST be just about format or looks, e.g. whitespace, a banner.       |
| `test`     | Add or change tests.                                                               |
| `build`    | Change the build process, or tools, or infrastructure, e.g. Makefile, Dockerfiles. |
| `ci`       | Change the continuous integration workflows.                                       |
| `conf`     | Change a tool configuration.                                                       |

A type tells what a commit is about. Avoid catch-all types, such as `chore`, which sidestep that
duty: when no type describes a change, add one that does.


Use semantic versioning
-----------------------

The project follows [semantic versioning](https://semver.org/spec/v2.0.0). The type of the summary
line sets the bump:

| Type                                                                       | Increments        |
|----------------------------------------------------------------------------|-------------------|
| `feat!`, `drop!`                                                           | SemVer MAJOR      |
| `feat`                                                                     | SemVer MINOR      |
| `fix`, `upgrade`, `perf`, `refactor`                                       | SemVer PATCH      |
| Any other: `drop`, `docs`, `style`, `test`, `build`, `ci`, `conf`          | no SemVer version |

Use `drop!` only when what goes was relied upon, and `feat!` for any other change that breaks what
users rely on, since both increment the MAJOR version. Use `drop` when nothing relies on what goes.

A `BREAKING CHANGE:` trailer means nothing: a change that is incompatible says so with its type.


Use trailers for metadata
-------------------------

Trailers end the message, one per line, in the style of email headers, with no blank line between
them. A trailer lists each co-author of a commit, by name and email address:

    Co-authored-by: Alice Adams <alice@example.com>
    Co-authored-by: Bob Brown <bob@example.com>

Others help to skim, search and look up related commits or URLs:

    Keywords: security, encryption, authentication
    Importance: high
    References: ...
    Supersedes: ...
    Obsoletes: ...
    See-Also: ...


Related links
-------------

Semantic commits are those of [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/),
without scopes, and with `feat!` and `drop!` as types of their own.

Blog posts about how to write Git commit messages:

  * [5 Useful Tips For A Better Commit Message by Caleb Thompson at Thoughtbot](https://robots.thoughtbot.com/5-useful-tips-for-a-better-commit-message)
  * [A Note About Git Commit Messages by tpope at tbaggery](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
  * [How to Write a Git Commit Message by Chris Beams](https://chris.beams.io/posts/git-commit/)
  * [Writing good commit messages by the Erlang OTP team](https://github.com/erlang/otp/wiki/writing-good-commit-messages)
  * [On commit messages by Who-T](http://who-t.blogspot.com/2009/12/on-commit-messages.html)
  * [Linus Torvalds advice on word wrap](https://github.com/torvalds/linux/pull/17#issuecomment-5661185)
  * [Writing commit messages by Simon Tatham](https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/commit-messages/)
