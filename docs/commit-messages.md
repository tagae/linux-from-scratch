Git Commit Message Conventions
==============================

Start with a summary line
-------------------------

Begin the message with a short summary line a.k.a. subject:

  * Start with an imperative present active verb: Add, Drop, Fix, Refactor, Optimize, etc.
  * Try to use up to 50 characters (convention used by the Git project itself).
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

  * Add foo
  * Drop foo
  * Fix foo
  * Refactor foo
  * Optimize foo

Summary keywords
----------------

We recommend these summary keywords because they use imperative mood, present tense, active voice, and are verbs:

  * **Add**: Create a capability e.g. feature, test, dependency.
  * **Drop**: Delete a capability e.g. feature, test, dependency.
  * **Fix**: Fix an issue e.g. bug, typo, accident, misstatement.
  * **Bump**: Increase the version of something e.g. a dependency.
  * **Make**: Change the build process, or tools, or infrastructure.
  * **Start**: Begin doing something; e.g. enable a toggle, feature flag, etc.
  * **Stop**: End doing something; e.g. disable a toggle, feature flag, etc.
  * **Optimize**: A change that MUST be just about performance, e.g. speed up code.
  * **Document**: A change that MUST be only in the documentation, e.g. help files.
  * **Refactor**: A change that MUST be just a refactoring patch
  * **Reformat**: A change that MUST be just a formatting patch, e.g. change spaces.
  * **Rearrange**: A change that MUST be just an arranging patch, e.g. change layout.
  * **Redraw**: A change that MUST be just a drawing patch, e.g. change a graphic, image, icon, etc.
  * **Reword**: A change that MUST be just a wording patch, e.g. change a comment, label, doc, etc.
  * **Revise**: A change that MUST be just a revising patch e.g. a change, an alteration, a correction, etc.
  * **Refit/Refresh/Renew/Reload**: A change that MUST be just a patch e.g. update test data, API keys, etc.

We recommend these summary keywords for things that don't fit into the above categories:

  * **Major**: Anything that causes a major version increase.
  * **Minor**: Anything that causes a minor version increase.
  * **Patch**: Anything that causes a patch version increase.

Real-world examples
-------------------

Real-world examples show how we use imperative mood, present tense, active voice, and verbs:

  * **Add** feature for a user to like a post
  * **Drop** feature for a user to like a post
  * **Fix** association between a user and a post
  * **Update** dependency library to current version
  * **Make** build process use caches for speed
  * **Start** feature flag for a user to like a post
  * **Stop** feature flag for a user to like a post
  * **Optimize** search speed for a user to see posts
  * **Document** community guidelines for post content
  * **Refactor** user model to new language syntax
  * **Reformat** home page text to use more whitespace
  * **Rearrange** buttons so OK is on the lower right
  * **Redraw** diagram of how our web app works
  * **Reword** home page text to be more welcoming
  * **Revise** link to update it to the new URL

Real-world examples for things that don't fit into the above categories:

  * **Major** overhaul of our API from version 1 to 2
  * **Minor** improvement of our API from version 1.1 to 1.2
  * **Patch** our API from version 1.1.1 to 1.1.2

Use semantic versioning
-----------------------

We use [semantic versioning](https://semver.org/spec/v2.0.0) for many of our projects:

  * **Add**, **Start**: Increment SemVer MINOR version when there is a new capability.
  * **Drop**, **Stop**: Increment SemVer MAJOR version when there is an incompatibility.
  * **Fix**, **Update**, **Make**, **Optimize**, **Document**: Increment SemVer PATCH version.
  * **Refactor**, **Reformat**, **Rearrange**, **Redraw**, **Reword**: Increment SemVer PATCH version.

Specifics for right and wrong
-----------------------------

Capitalize the summary.

  * Right: Add feature
  * Wrong: add feature

Finish the summary without a sentence-ending a period.

  * Right: Add feature
  * Wrong: Add feature.

If the summary ends with an non-sentence-ending period, use it.

  * Right: Add feature for U.S.A.
  * Wrong: Add feature for U.S.A

Use imperative mood: present tense, active voice, and lead verb.

  * Right: Add feature
  * Wrong: Adds feature (this is indicative mood, not imperative mood)
  * Wrong: Added feature (this is past tense, not present tense)
  * Wrong: Adding feature (this lead is a gerund, not a verb)
  * Wrong: Feature added (this is passive voice, not active voice)

Specifics for length
--------------------

Keep the summary line within 50 characters.

  * The purpose is easy readability.
  * This is the Git official convention.
  * This is the same convention as writing an email message.

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

We reject Git commit message styles that put meta-information into the summary line.

Example:

  * [bug] ...
  * (release) ...
  * \#12345 ...
  * docs: ...
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

    Fix foo

    The fix changes how we parse the input. See [the issue](https://example.com/25)
    for details.


Use keywords, importance, references, etc.
------------------------------------------

We like to use commit message trailers to help us skim, search, and prioritise.

To keep track of these, we write a Git commit message body that uses email header conventions.

Example:

    Fix foo

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

Blog posts about how to write Git commit messages:

  * [5 Useful Tips For A Better Commit Message by Caleb Thompson at Thoughtbot](https://robots.thoughtbot.com/5-useful-tips-for-a-better-commit-message)
  * [A Note About Git Commit Messages by tpope at tbaggery](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
  * [How to Write a Git Commit Message by Chris Beams](https://chris.beams.io/posts/git-commit/)
  * [Writing good commit messages by the Erlang OTP team](https://github.com/erlang/otp/wiki/writing-good-commit-messages)
  * [On commit messages by Who-T](http://who-t.blogspot.com/2009/12/on-commit-messages.html)
  * [Linus Torvalds advice on word wrap](https://github.com/torvalds/linux/pull/17#issuecomment-5661185)
  * [Writing commit messages by Simon Tatham](https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/commit-messages/)
