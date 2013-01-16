Squash: A squarish bug spray
============================

**An open-source project from Square**

Squash is a collection of tools that help engineers find and kill bugs in their
code. Squash consists of the following components:

* **Client libraries:** Client libraries for different systems (Ruby, Ruby on
  Rails, Cocoa with Objective-C, etc.) catch and record errors when they occur,
  then send them to the API endpoint. Client libraries can be found under the
  [SquareSquash organization](https://github.com/SquareSquash).
* **Front-end:** This website displays Bug information and helps the engineer
  find the root cause for a Bug, and fix it. It also lets engineers manage,
  assign, and comment on Bugs, as well as view statistics about the Bug.
* **API endpoints:** These routes (part of the front-end app) receive exception
  notifications from the client libraries and process them.

This project is the front-end and the API.

How to Install
--------------

To get started, run the `setup.rb` file in the project root. This script will
ask you a series of questions and generate a preliminary configuration for your
site install. When the script is completed, you can run `git status` to see what
files it changed, and refine your configuration from there.

Once the script is complete, Squash should run for most typical development
environments. Simply run `rails s` and visit the site in your Web browser. You
should be able to start using it immediately. You can also verify correctness by
running `rspec spec`.

Configuring and deploying the production instance is entirely up to you and your
particular production environment.

Additional configuration options can be found in the following locations:

* `config/application.rb`
* `config/environments/*.rb`
* `config/environments/*/*.yml`

If you don't see what you're looking for in any of those files, you'll probably
have to change the code to make it work. Don't be afraid -- the code is
thoroughly documented and should (hopefully) be very accessible.

### Requirements

Squash requires the following:

* Ruby 1.9.2 or newer (JRuby with `--1.9` is supported)
* Multithreading support (see the next section)
* PostgreSQL 8.4 or newer
* The Bundler gem
* Git 1.7 or newer

### Notes on some of the gem and library choices

**Why do you specifically require PostgreSQL?** Squash uses a lot of
PostgreSQL-specific features to make efficient use of the database and maintain
referential integrity, such as:

* foreign key constraints,
* triggered cached counters,
* check constraints, and
* semantic indexes for text-based search.

If PostgreSQL is out of the question, some of these features can be ported to
other RDBMSes; simply edit the `InitialSchema` migration and update the SQL as
necessary. If portability is required, a lot of these features can be
reimplemented in the Rails layer (e.g., cached counters), at the risk of
degraded referential integrity. (If you are reimplementing the cached counters
in Ruby, be sure to modify the `config/initializers/active_record.rb` file as
appropriate.)

If you do successfully port Squash to another RDBMS, let me know. I'd be happy
to take your changes.

**Why do you bundle an edge version of Rails?** The `3-2-stable` branch of Ruby
on Rails includes some changes to Active Record that are required by Squash's
multithreaded concurrency model (see next question). In particular, that version
of Active Record includes crucial changes to the connection pool and connection
reopening logic. If you do not wish to use edge Rails, you can drop the Gemfile
entry back down to a release version, provided you are using an alternative
concurrency model (e.g., Resque workers), or have backported the necessary
changes. In the future, when these changes are released, the Gemfile will be
altered.

**Why do you use threads to accomplish background tasks instead of fibers or
Resque workers?** Squash was originally built for Square, which runs all its
services on JRuby. Using threads is very efficient in JRuby, and avoids the
overhead of having to deploy both a website and workers. (It was hard enough
just getting the website alone up on production.)

If you are running Squash in a non-thread-safe (or multithreading-unfriendly)
environment, it should be easy to convert to a Resque-based environment. All
threaded code is encapsulated in worker classes that respond to a `.perform`
method, making them Resque-ready. Simply locate all occurrences of
`Multithread.spinoff` in the code and replace it with calls to `Resque.enqueue`.

If you do this successfully and wish to save future Squash users the effort,
feel free to turn your changes into a pull request.

**Why aren't you using RedCarpet?** As mentioned above, Squash was originally
built to run under JRuby. RedCarpet has compiled C extensions; Kramdown is pure
Ruby.

**Why do you require a recent version of Git?** Squash uses the
`git clone --mirror` command to create local mirrors of client projects' Git
repositories.

**Why don't you have integration tests or acceptance tests?** To be 100% honest,
lack of familiarity on these things in Ruby/Rails. Happy for any help people
want to extend towards this goal.

**Why are you using Erector?** I like Erector.

Documentation
-------------

Comprehensive documentation is written in YARD- and Markdown-formatted comments
throughout the source. To view this documentation as an HTML site, run
`rake yard`.

CoffeeScript libraries are documented using the YARD format as well, but YARD
does not as yet recognize them as documentable files. A `.codoopts` file is
included in case you wish to use [Codo](https://github.com/netzpirat/codo) to
generate the CoffeeScript docs, but as of now Codo does not recognize the ERb
files, and does not use the full set of Markdown syntax features used in the
documentation.

Project Overview
----------------

### Views

This is a pretty typical Rails website, save for the views, which are written
using Erector. The views forgo the traditional Rails concepts of partials and
templates in favor of analogous OOP concepts more familiar to software
developers: methods and inheritance. All views inherit from an abstract Erector
widget which provides layout; and all views have their content split into
multiple private methods.

In addition to the usual helpers (in `app/helpers`), there are view mixins under
`app/views/additions` that simplify view coding.

Embedded code snippets are all rendered using the {ProjectsController#context}
action. This action loads the appropriate file and revision from the Git
repository and returns a snippet plus the name of the SyntaxHighlighter brush to
use. The brush is determined from the file name/extension; the mapping can be
found in `data/brushes.yml`.

This view behavior is provided from a JavaScript library file in
`lib/assets/javascripts`. There are many similar helper classes in there; they
are documented but the documentation is not recognized by YARD and so is not
included in this documentation set.

JavaScript files are organized into four possible locations:

* Third-party JavaScript libraries are in `vendor/assets/javascripts` and
  loaded in the `application.js` manifest.
* JavaScript modules or helpers that are not specific to a particular page or
  site area are in `lib/assets/javascripts` and also loaded in `application.js`.
* JavaScript modules or helpers specific to a particular area of the site are in
  `app/assets/javascripts` and also loaded in `application.js`.
* Small JavaScript snippets, glue code, or other code intended to add dynamic
  behavior to a specific page is in a `.js` file named the same as, and placed
  alongside, the `.html.rb` view file. For example, if
  `app/views/projects/new.html.rb` needed a bit of JS glue code, it would be
  placed in `app/views/projects/new.js`. This code is placed in a `<SCRIPT>` tag
  at the end of the view by the {Views::Layouts::Application#inline_javascript}
  method.

CSS files are similarly organized:

* Third-party CSS files are in `vendor/assets/stylesheets` and loaded in the
   `application.css` manifest.
* CSS styles or helpers global to the entire website are in
  `lib/assets/stylesheets` and also loaded in `application.css`.
* CSS styles specific to a single page or a related group of pages are placed in
  `app/assets/stylesheets` and also loaded in `application.css`. Each `<BODY>`
  tag is given a class name equal to the controller name, and an ID equal to
  the controller and action name separated with a dash. For instance, the
  `projects/new` action's body would be `<body class=projects id=projects-new>`.

### Controllers

For information about requests and responses, see {ApplicationController}.

### Models

Models make extensive use of advanced PostgreSQL features for efficiency and
convenience. Cached counters are updated using triggers and rules, foreign key
constraints and hooks are enforced at the database level, and validations are
backed up by corresponding `CHECK` triggers. This helps ensure referential and
data integrity even in situations where Rails fails, or outside of the Rails
stack. See the various migrations to learn more about the triggers, rules, and
constraints being used.

Observers are used for more high-level triggers, such as creating {Event Events}
at the appropriate times, or sending emails. See the classes in
`app/models/observers` for more.

Models also use the HasMetadataColumn gem to reduce their width and incorporate
schemaless data. Most models have a JSON-formatted `metadata` column to which
new information can be added or removed without having to create new migrations.

### Tasks

Various Rake tasks are available under `lib/tasks`. These include tasks for
pruning and maintaining the database, development tasks, and configuring the
workers.

### Workers

Workers are found in the `lib/workers` directory. Along with OccurrencesWorker,
which stores and categorizes Occurrences, there are other workers for managing
Deploys and other minor tasks. These workers are run asynchronously using
{Multithread}.

### Mailers

Notification mails are sent by the {NotificationMailer}. It and any other
mailers live in `app/mailers`.

`NotificationMailer` conditionally delivers emails. An email will only be
delivered if all of the following conditions are met:

* The Project has a mailing list email configured (for the critical-bugs and
  all-bugs mailing lists),
* the Environment's `sends_emails` attribute is `true`, and
* the User has enabled receipt of that category of emails (typically specified
  in the Membership).

### Authentication and Authorization

Authentication is done using either password verification or LDAP; see
{AuthenticationHelpers} and related controller mixins, as well as the
model mixins under `app/models/additions` for more information.

There are four permissions levels that a User can have, specific to an
individual Project:

**Non-members** do not have a {Membership} record with a Project. They can view
Bugs and Occurrences, view the Project's API key, view the list of other
Project members, watch Bugs, and comment on Bugs.

**Members** can do everything non-members can do, and can also assign Bugs, be
assigned Bugs, and modify/delete Bugs.

**Administrators** can do everything members can do, and can also modify
Project and Environment settings, regenerate the API key, promote and demote
members to administrator status, and modify/delete others' Comments.

**Owners** (each Project has only one) can do everything administrators can do,
and can also delete the Project and reassign ownership.

Recording and Categorizing Occurrences
--------------------------------------

### Client-Specific Information

The client library identifiers used throughout the website determine how a Bug
reported from that library is presented in the view. The
{OccurrencesController::INDEX_FIELDS} constant maps a client library identifier
to the relevant summary fields to display in the list view.

Each occurrence is transmitted with the name of the client library; the
{Occurrence} records this to the `client` field. The {Bug}'s `client` field is
set from the first Occurrence's; in general, one should expect that all
Occurrences of a Bug share the same client value.

Regardless of the Occurrence's client value, all fields for which there is data
are displayed in the Occurrence view.

If a client library is updated to add new information fields, all that is needed
is to update the `has_metadata` hash in Occurrence with the new fields, and to
update the `occurrences#show` view as necessary. (The `INDEX_FIELDS` hash can
also be updated as appropriate.)

If a new client library is added, in addition to doing the above for any new
fields unique to the new client, the `INDEX_FIELDS` hash will need to be
expanded to include the new client.

### Queue Consumer

For information about the background worker that converts incoming exception
information into Occurrence and Bug records (including doing "best guess" commit
blaming, determining which Occurrences share the same root Bug, etc.), see the
documentation for the {OccurrencesWorker} module. See also **Static Analysis**
below.

### Deploys and Releases

Squash can handle both _deployed_ projects (hosted projects for which typically
only one version is live at a time) and _released_ projects (distributed apps
for which many versions may exist "in the wild").

If you are developing a released project, you must associate your {Deploy}
objects with a unique version identifier (such as a build number). You must also
send the correct build identifier with every occurrence report. See the client
library and API controller documentation for more information.

Once this is done, Squash's behavior is changed slightly: Bugs that are fixed
in an older release, but recur, are not reopened. Bugs that are fixed in an
older release but then recur in newer releases are treated as completely
separate Bugs.

This app exposes an API endpoint for notifying Squash of new releases/deploys of
your Project. You should notify Squash whenever you deploy your Project (or
release a new version) so that it can properly manage Bugs (automatically mark
fixed Bugs as deployed, associate new Bugs with the new Deploy, etc.).

Most client libraries include an easy means to add this feature to your deploy
or release process.

Static Analysis
---------------

### Message Normalization

When an Occurrence is grouped into a Bug, its message is stripped of any
non-relevant or situational information. (Note that since the message is not
used as a dimension in grouping Occurrences, two Occurrences of the same Bug
could have completely different messages. A Bug gets its message from its first
Occurrence.) This is done by the {Blamer}.

For most messages, this is done using simple regex subsitution. Squash can also
normalize an exception's message using a list of known message templates. Such
templates are stored in the `data/message_templates.yml` file. The file contains
a hash mapping exception class names to an array of arrays. Each inner array
contains two elements: the regexp to match the exception message on, and the
replacement message should it match.

These templates are evaluated in the order they appear in the array. Scripts
that regenerate the templates for MySQL and PostgreSQL error strings can be
found under the `script` directory.

### Version Control Systems

As of now, Squash is only compatible with projects that are version-controlled
using Git. However, in the interest of remaining as VCS-agnostic as possible,
commit identifiers are never called "SHA1s," but instead "IDs."

### Unsymbolicated, Obfuscated, or Minified Stack Traces

Client libraries of compiled, obfuscated, or minified applications will need to
convert their stack traces in order for them to be of use for static analysis.
Because release builds are typically not distributed with embedded decompilation
information, a mapping or table must be given to Squash, so that when Squash
receives an unconverted stack trace, it can perform lookups and convert it to a
more usable format.

Currently, the supported conversions are:

* symbolication of iOS exceptions (see {Symbolication}),
* deobfuscation of Java exceptions (see {ObfuscationMap}),
* and source-mapping of JavaScript exceptions (see {SourceMap}).

Client libraries are responsible for delivering the raw stack trace data to
Squash when an exception occurs, and for delivering lookup tables to Squash upon
each new release. {Api::V1Controller} has endpoints for these purposes in
various languages.

Unconverted stack traces are stored in a particular format; see {Occurrence} for
more information. When a new exception with a stack trace in this format is
received, Squash immediately attempts to convert it using an existing matching
lookup table. If no such table is found, the stack trace is left unconverted. It
can still be viewed on the front end. When, later, a new lookup table is added,
Squash automatically finds and converts any matching stack traces.

Because every new Occurrence must be assigned a Bug (including unconverted
Occurrences), it is possible that the "blamed" `file` and `line` fields of the
Bug could themselves be unconverted. The {Bug} class has provisions to support
this; see in particular {Bug#displayable_file?}.

Specs
-----

All models, controllers, and library files are unit-tested with RSpec specs
under the `spec` directory. Run unit tests with the `rspec spec` command. Views
and JavaScript files are not specced. No integration or acceptance tests are
written. Almost all unit tests use factories rather than mocks, putting them
somewhat closer to integration tests.

In general, the test environment is identical to the development/production
environment, save for the usual Rails allowances, and the
`config/initializers/active_record_observer_hooks.rb` file. This file adds
after-commit hooks to observers (identical to those available to models).
However, specs are transactionalized, meaning that these hooks wouldn't run
until after the spec is completed, resulting in multiple spec failures.

To remedy this, the file introspects on the environment, and instead links the
observer hooks to the `after_save` model hooks in the test environment. This
differentiates the test and live environments, but allows specs to pass.

If you wish to bring your test environment closer to production, you can set
the `use_transactional_fixtures` RSpec setting to false. The hooks file will
automatically detect the change and use the correct `after_commit` hooks.
Currently, all specs pass with and without transactionalized fixtures.

Third-Party Integrations
------------------------

Squash supports integration with a handful of popular other developer tools.

### PagerDuty

When Squash is integrated with PagerDuty, it will begin sending exceptions to
PagerDuty once the Occurrence count for a given Bug exceeds the Project's
critical threshold. Thereafter, every Occurrence is sent to PagerDuty as a
trigger. The triggers are grouped into alerts by Bug, so users will only be
paged once per new error.

In addition, marking a Bug fixed will also automatically resolve its associated
PagerDuty alert (if any), and assigning a Bug or marking it irrelevant
automatically acknowledges any associated PagerDuty alert.

In order to integrate Squash with PagerDuty, you must

1. generate an API key that Squash can use for PagerDuty access (you must be a
   PagerDuty admin to do this),
2. update the `config/environments/common/pagerduty.yml` file to enable
   PagerDuty integration anmd provide the API key,
3. configure Generic API services for each escalation policy you wish to use,
   and
4. set the PagerDuty-related options in your Project's configuration page.

### JIRA

When Squash is integrated with JIRA, users have the option of associating a JIRA
issue with any Bug. The Management tab will then display a link allowing the
user to quickly view the associated issue.

In addition, the user can have Squash watch the JIRA issue for status updates.
Once the JIRA issue is resolved (or is changed to someother specified status),
the Bug can be automatically marked as fixed. By associating multiple Bugs with
one JIRA issue in such a manner, a user can quickly fix a large number of Bugs
by closing just one JIRA issue.

Finally, a "Create JIRA Issue" button is provided on the Management tab allowing
users to easily create new JIRA issues for any Bug.

In order to integrate Squash with JIRA, you must

1. configure the `config/environments/common/jira.yml` file with your
   JIRA authentication credentials and installation location, and
2. add a cron job or other periodic task that runs `rake jira:update`.

JIRA integration works out-of-the-box if you use username/password
authentication. OAuth authentication requires a few more steps. Because OAuth
authentication requires user actions, you will need to obtain an access token
and secret which the JIRA client can use without needing to prompt the user. You
can do this by running the `jira_oauth.rb` script:

```` ruby
rails runner script/jira_oauth.rb
````

Follow the instructions to set up your JIRA integration.
