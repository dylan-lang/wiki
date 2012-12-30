wiki
====

This library is a wiki written in the Dylan language.  It supports the
following features:

  * All data is stored in a git repository so it can be edited offline
    if desired, backed up, reverted, etc.

  * Account verification.

  * Access controls -- each page in the wiki can be restricted to
    being viewed or edited by specific sets of users.

  * Page markup based on `ReStructured Text (RST)
    <http://docutils.sourceforge.net/rst.html>`_


Configuration
=============

You will need to tweak these values in the config file:

* **http-server.wiki.git-main-repository-root** -- Make it point to the root
  directory of your wiki git repository.  Example::

     $ cd
     $ mkdir wiki-data
     $ cd wiki-data
     $ git init

     <wiki git-main-repository-root = "/home/you/wiki-data" ...>

* **http-server.wiki.git-user-repository-root** -- Make this point to the
  root directory of the user data repository.  This is separate from
  the page and group data so that it can easily be backed-up
  separately (e.g., by pushing to a different remote).  Example::

     $ cd
     $ mkdir wiki-user-data
     $ cd wiki-user-data
     $ git init

     <wiki user-repository = "/home/you/wiki-user-data" ...>

* **http-server.wiki.git-executable** -- If the "git" executable is not on the
  path of the user running the wiki, then you need to specify it in
  the <wiki> element::

     <wiki git-executable = "/usr/bin/git" ... />

* **http-server.wiki.static-directory** -- Make it point at the "www" subdirectory
  (I guess this should be made relative to <server-root>.)

* **http-server.wiki.administrator.password** -- Choose a password you like.

* **http-server.wiki.rst2html** -- Path to the rst2html executable.


Startup
=======

Build the library and then run it like this::

   wiki --config config.xml


Markup Language
===============

The markup language is an augmented version of `ReStructured Text
(RST) <http://docutils.sourceforge.net/rst.html>`.  An initial pass is
made over the markup source to resolve wiki-specific markup and then
the resulting text is passed directly to rst2html.

All wiki directives start with ``{{`` and ends with ``}}``.  Because
page links are expected to be the most common by far, they have an
optional shortened syntax::

    {{page: Foo, text: Bar}}    -- link text "Bar" to page "Foo"
    {{Foo,Bar}}                 -- shorthand for {{page:Foo,text:Bar}}
    {{Foo}}                     -- shorthand for {{page:Foo,text:Foo}}
    {{page: "x,y"}}             -- names may be quoted
    {{page: 'The "x" Page'}}    -- single or double quotes work.
    {{user: jdoe, text: Jon}}   -- a user link
    {{group: group}}            -- a group link
    {{escape: "[[" "]]"}}       -- use [[ and ]] instead of {{ and }}

The wiki pre-parser knows nothing about RST parsing.  It simply
searches the raw markup for ``{{`` and assumes that's a wiki
directive.  If you need to put a literal ``{{`` or ``}}`` in the
generated output it can be done by changing the escape character
sequences::

  {{escape: "[[" "]]"}}
  Now {{ and }} are just normal text and [[Foo]] is a page link.
  [[escape: "{{" "}}"]]


Dev Guide
=========

Admin
-----

The wiki repositories (main content and user data) make use of the
"git notes" feature to store meta-data about each commit.  Becaues of
this they need some special attention when pushing/pulling.

Clone::

  $ git clone git@github.com:cgay/dylan-wiki-data
  $ git pull origin refs/notes/commits:refs/notes/commits

Push::

  $ git push origin
  $ git push origin refs/notes/commits

Pull::

  $ git pull origin
  $ git pull origin refs/notes/commits:refs/notes/commits



Data File Layouts
-----------------

All wiki data are stored in a git repository.  "Public" data is stored
in one repository and "private" data in another.  The only private
data is the user database.  Pages and groups are stored in the public
repo.

In order not to end up with too many files in a single directory
(which may just be a superstition these days, and is really only a
worry for pages anyway) users, groups, and pages are divided into
subdirectories using the first few letters of their name/title.  e.g.,
a page entitled "Green Stripe" would be stored in the directory named
``sandboxes/main/Gre/Green Stripe/``.  Similarly for users and groups,
although they use a shorter prefix on the theory that there will be a
lot fewer of them.

Example::

  <public-repo-root>/
    groups/
      a/
        <a-group-1>
        <a-group-2>
	...
      b/
        <b-group-1>
        <b-group-2>
	...
      c/
      ...
        
    pages/
      <sandbox-1>/
        <prefix-1>/
	  <page-name-1>/content  # page markup
	  <page-name-1>/tags     # page tags
	  <page-name-1>/acls     # page ACLs
	  <page-name-1>/links    # pages that link to this page
	  <page-name-2>/content
	  <page-name-2>/tags
	  <page-name-2>/acls
	  <page-name-2>/links
	  ...
	<prefix-2>/
	  ...
      <sandbox-2>/
        <prefix-1>/
	  <page-name-1>/content
	  <page-name-1>/tags
	  <page-name-1>/acls
	  ...

  <private-repo-root>/
    users/
      a/
        <a-user-1>
	<a-user-2>
	...
      b/
        <b-user-1>
	<b-user-2>
	...
      ...
      z/

The default sandbox name is "main" and currently there is no way to
create new sandboxes.  In some other wikis these would be called
"wikis".  The format of each file is described below.

content
    The ``content`` file contains the raw wiki page markup text and
    nothing else.

tags
    The ``tags`` file contains one tag per line and nothing else.  Tags may
    contain whitespace.

acls
    The ``acls`` file has the following format::

        owner: <username>
        view-content: <rule>,<rule>,...
        modify-content: <rule>,<rule>,...
        modify-acls: <rule>,<rule>,...

    Rules are defined by the following pseudo BNF::

        <rule>   ::= <access><name>
	<access> ::= - | +              // '-' = deny, '+' = allow
	<name>   ::= <user> | <group> | $any | $trusted | $owner
	<user>   ::= any user name
	<group>  ::= any group name

    The special name "$any" means any user, "$trusted" means logged in users
    and "$owner" means the page owner.  "$" is not allowed in user or group
    names so there is no conflict.

<a-group-1>
    iso8601-creation-date
    name:owner:member1:member2:...
    <n-bytes>
    ...description in n bytes...

<a-user-1>
    iso8601-creation-date
    username1:Real Name:admin?:password:email:activation-key:active?

    Passwords are stored in base-64 for now, to be slightly better
    than clear text.  This must be improved.  Email is also in
    base-64.

