Git Commit Message Conventions
==============================

Start with a summary line
-------------------------

Begin the message with a short summary line a.k.a. subject, in the form of a semantic commit:

    <type>: <subject>

  * Start with a type that tells what the commit does: `feat`, `fix`, `refactor`, etc. (see below).
  * Use one of the types below: a type is a word of its own, and `feat!` is as much a type as `feat`.
    There are no scopes, as in `feat(virt):`.
  * Start the subject with an imperative present active verb, in lowercase: add, drop, fix, etc.
  * Use up to 72 characters for the whole line.
  * Finish without a sentence-ending period.


Continue with a longer description
----------------------------------

Continue with a longer description a.k.a. message body:

  * Add a blank line after the summary line, then write as much as you want.
  * Use up to 72 characters per line for typical text for word wrap.
  * Use as many characters as needed for atypical text, such as URLs, terminal output, formatted messages, etc.
  * Include any kind of notes, links, examples, etc. as you want.

Summary examples
----------------

Summary examples of good commit messages:

  * feat: add foo
  * drop: remove foo
  * fix: stop foo from hanging
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
| `fix`      | Fix an issue e.g. bug, typo, accident, misstatement, or an insecure package.       |
| `perf`     | A change that MUST be just about performance, e.g. build faster or ship less.      |
| `refactor` | A change that MUST be just a refactoring: it changes nothing that users can see.   |
| `drop`     | Delete a capability that nothing relies on e.g. feature, option, package, command. |
| `drop!`    | Delete a capability that users rely on.                                            |
| `docs`     | A change that MUST be only in the documentation or in comments.                    |
| `style`    | A change that MUST be just about format or looks, e.g. whitespace, a banner.       |
| `test`     | Add or change tests.                                                               |
| `build`    | Change the build process, or tools, or infrastructure, e.g. Makefile, Dockerfiles. |
| `ci`       | Change the continuous integration workflows.                                       |
| `chore`    | Any other upkeep, e.g. bump a dependency that has no vulnerability, remove a file. |
| `conf`     | Change the configuration of Claude or of another tool.                             |

Use semantic versioning
-----------------------

We use [semantic versioning](https://semver.org/spec/v2.0.0) for many of our projects. The type of
the summary line sets the bump:

| Type                                                                       | Increments        |
|----------------------------------------------------------------------------|-------------------|
| `feat!`, `drop!`                                                           | SemVer MAJOR      |
| `feat`                                                                     | SemVer MINOR      |
| `fix`, `perf`, `refactor`                                                  | SemVer PATCH      |
| Any other: `drop`, `docs`, `style`, `test`, `build`, `ci`, `chore`, `conf` | no SemVer version |

Use `drop!` only when what goes was relied upon, and `feat!` for any other change that breaks what
users rely on, since both increment the MAJOR version. Use `drop` when nothing relies on what goes.

A `BREAKING CHANGE:` trailer means nothing: a change that is incompatible says so with its type.

Specifics for right and wrong
-----------------------------

Start the subject with a lowercase letter.

  * Right: feat: add feature
  * Wrong: feat: Add feature

Finish the summary without a sentence-ending period.

  * Right: feat: add feature
  * Wrong: feat: add feature.

If the summary ends with an non-sentence-ending period, use it.

  * Right: feat: add feature for U.S.A.
  * Wrong: feat: add feature for U.S.A

Use imperative mood: present tense, active voice, and lead verb.

  * Right: feat: add feature
  * Wrong: feat: adds feature (this is indicative mood, not imperative mood)
  * Wrong: feat: added feature (this is past tense, not present tense)
  * Wrong: feat: adding feature (this lead is a gerund, not a verb)
  * Wrong: feat: feature added (this is passive voice, not active voice)

Specifics for length
--------------------

Keep the summary line within 72 characters.

  * The purpose is easy readability, in the log and on the web, where longer lines get cut.

Use a blank line after the summary line.

  * The purpose is making the commit message parseable by tools.
  * This is the Git official convention.
  * This is the same convention as writing an email message.

Use up to 72 characters per line for typical text for word wrap.

  * The purpose is easy readability on typical terminals.
  * This is the Git official convention.
  * This is the same convention as writing an email message.

Use as many characters as needed for atypical text, such as URLs, output, formatted messages, etc.

  * The purpose is preserving important formatting.
  * This is the Git official convention.
  * This is the same convention as writing an email message.


Reject these formats
--------------------

We reject Git commit message styles that put other meta-information into the summary line.

Example:

  * [bug] ...
  * (release) ...
  * \#12345 ...
  * JIRA-666 #time 1w 2d 4h 30m #comment Task completed ahead of schedule #resolve

We reject using a ticket ID number in the summary line.

  * Instead, we pass it as a commit message trailer (e.g., `Issue: 25`).


Use trailers to signal co-authorship
------------------------------------

We sometimes have more than one person working on a commit. For example, we do do pair programming.

To keep track of this, we write a Git commit message trailer that lists each person. We use the
person's name and the email address. We use one person per line because this is easy to parse.

    Co-authored-by: Alice Adams <alice@eaxmple.com>
    Co-authored-by: Bob Brown <bob@example.com>
    Co-authored-by: Carol Curtis <carol@example.com>


Use Markdown in body
--------------------

To refer to external links, we use Markdown links.

  * Use Markdown links for external references, e.g. [text](https://example.com).
  * Use Markdown code blocks for terminal output, formatted messages, etc.
  * Use Markdown lists for enumerating changes, notes, etc.
  * Use Markdown headings for long messages with multiple topics.

Example:

    fix: parse the input of foo

    The fix changes how we parse the input. See [the issue](https://example.com/25)
    for details.


Use keywords, importance, references, etc.
------------------------------------------

We like to use commit message trailers to help us skim, search, and prioritise.

To keep track of these, we write a Git commit message body that uses email header conventions.

Example:

    fix: parse the input of foo

    Keywords: security, encryption, authentication
    Importance: high
    References: ...
    Supersedes: ...
    Obsoletes: ...
    See-Also: ...

We use some of these to help our teams focus on the most important work.

  * When a commit message says "Importance: high" then it gets priority for code review and also for testing on the continuous integration server.
  * When a commit message says "Supersedes", "References", "Obsoletes", then we can easily look up the earlier commits or URLs.


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
