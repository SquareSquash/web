Building a Client Library for Squash
====================================

If you want to use Squash in your project, a client library must exist for your project's language. You may also want a more specific client library for your particular framework. (For example, there is a general Squash Ruby client library, and a Squash Rails client library that adds additional HTTP information to exception notifications.)

A list of existing client libraries is kept up-to-date in the [Squash Web README file](https://github.com/SquareSquash/web/blob/master/doc/README_FOR_APP.md).

If your language or framework isn't in this list, you'll have to write your own client. Don't worry; it's easy.

General Information
-------------------

Projects are uniquely identified by an API key (UUID), which also serves to authenticate the client library. Each project can have multiple environments. No specific definition is given for the concept of an environment; it's entirely up to the Squash user. They typically correspond to Rails environments, or perhaps release channels of an iOS project.

The Squash API
--------------

The API has the following endpoints:

### Notifying Squash of a new exception

**Request:** `POST /api/1.0/notify`

**Body:** JSON-formatted hash with the following **required** fields:

|               |                                                                                                                          |
|:--------------|:-------------------------------------------------------------------------------------------------------------------------|
| `api_key`     | The project's API key. Typically this is configured by the API user.                                                     |
| `environment` | The environment name (e.g., "production"). Also configured by the API user.                                              |
| `client`      | A constant string identifying this client.	 																		   |
| `backtraces`  | An array of backtraces of every relevant thread or fiber at the time of the crash (see Backtrace Format below for more). |
| `class_name`  | The name of the exception class.                                                                                         |
| `message`     | The exception message.                                                                                                   |
| `occurred_at` | The time of occurrence, RFC 2822 format.                                                                                 |

If your client library is for **deployed, hosted applications**, you must also include a `revision` field with the Git SHA of the deployed revision. If your client library is for **distributed, installed applications**, you must also include a `build` field with a uniquely-identifying build number.

There are a myriad other optional fields you can provide with additional information about your exception. For example, if it occurred on a mobile device, you could provide the `operating_system` field. A complete list is available at https://github.com/SquareSquash/web/blob/master/app/models/occurrence.rb -- see the class comments and the `has_metadata_column` call.

You can include any arbitrary fields you like that aren't in the list; they will be displayed on the occurrence "User Data" tab. If your client library records data that you wish add native support for in Squash, see "Adding Your Own Data Fields" below.

**Responses:**

* `200 OK`: Exception received and recorded.
* `422 Unprocessable Entity`: Invalid request body. Perhaps required fields were missing.
* `403 Forbidden`: Unrecognized API key.

### Notifying Squash of a new deploy or build

**Request:** `POST /api/1.0/deploy`

**Body:** JSON-formatted hash with the following **required** fields:

|                       |                                                                     |
|:----------------------|:--------------------------------------------------------------------|
| `project[api_key]`    | The project's API key. Typically configured by the API user.        |
| `environment[name]`   | The name of the environment that was deployed (e.g., "production"). |
| `deploy[revision]`    | The Git SHA1 of the deployed or released revision.                  |
| `deploy[released_at]` | The time of release or deploy.                                      |

If your client library is for **deployed, hosted applications**, you must also include a `deploy[hostname]` field with the name of the computer where the deploy was initiated. If your client library is for **distributed, installed applications**, you must also include a `deploy[build]` field with a uniquely-identifying build number.

**Responses:**

* `200 OK`: Deploy received and recorded.
* `422 Unprocessable Entity`: Invalid request body. Perhaps required fields were missing.
* `403 Forbidden`: Unrecognized API key.

### Sending a symbolication to Squash

**Request:** `POST /api/1.0/symbolication`

**Body:** JSON-formatted hash with the following **required** fields:

|                          |                                                                                   |
|:-------------------------|:----------------------------------------------------------------------------------|
| `symbolication[uuid]`    | The unique identifier for the symbolication (e.g., the output of `dwarfdump -u`). |
| `symbolication[symbols]` | Symbol data; JSON-serialized, gzipped, and base-64-encoded.                       |
| `symbolication[lines]`   | Lines-of-code data; JSON-serialized, gzipped, and base-64-encoded.                |

For more specific information on those last two fields, see the [Squash iOS Symbolicator](https://github.com/SquareSquash/ios_symbolicator).

**Responses:**

* `201 Created`: Symbolication received and recorded.
* `422 Unprocessable Entity`: Invalid request body.

### Sending a source map to Squash

**Request:** `POST /api/1.0/sourcemap`

This API endpoint is still a work in progress. It will be used for sending source maps (e.g., CoffeeScript-to-JavaScript or JavaScript-to-minified) to Squash.

Backtrace Format
----------------

Squash supports recording multiple backtraces for a single exception, and recording special kinds of backtrafces. The format of the `backtraces` field allows this. The field takes the following JSON format:

```` json
[
  ["Thread 0", true, [
     ["file/path.rb", 123, "method_name"],
     ...
  ]],
  ...
]
````

So, the outermost array is a list of threads. Each entry in that array has three elements:

* the name of the thread (client-specific),
* whether or not the thread was responsible for the exception, and
* the backtrace array.

Each element of the backtrace array is an array consisting of

* the file path (relative to the project root for non-library files),
* the line number, and
* the method or function name (or `null`).

For certain special cases, this array will consist of other than three elements. These special cases are:

### Unsymbolicated backtrace lines

If a line in the backtrace is not yet symbolicated, it is stored in a different format. Each unsymbolicated line of a backtrace becomes a _two_-element array. The first element is the constant `_RETURN_ADDRESS_`, and the second is an integer stack trace return address.

### Un-sourcemapped JavaScript files

If a line in a backtrace corresponds to a JavaScript asset that has not yet been mapped to an un-minified source file, it is stored as a six-element] array:

0. The constant `_JS_ASSET_`
1. The URL of the JavaScript source file
2. The line number
3. The column number
4. The function name
5. The arguments passed to the function

Some elements will be `null` depending on browser support.

Nested or Wrapped Exceptions
----------------------------

This class can record exceptions that have been nested underneath one or more parent exceptions, paradigm that can be seen occasionally in Ruby (e.g., `ActionView::TemplateError`) and far too frequently in Java. It is up to the individual client libraries to detect and record nesting parents.

If an exception was nested underneath parent(s), the `parent_exceptions` property should be an array of hashes, each hash representing a parent exception, ordered from innermost to outermost parent. Each hash takes the following keys:

* `class_name` (the name of the exception class)
* `message`
* `backtraces`
* `ivars`
* `association` (the name of the instance variable containing the inner exception, or some other identifier as to how the two exceptions are associated)

The values for these keys are the same as the top-level fields with the same name unless otherwise specified. The `association` field is optional.

Adding Support for Client Library in Squash
-------------------------------------------

Typically no changes are needed to support your new client library. However, there are some things you can do to improve that support:

### Update `OccurrencesController::INDEX_FIELDS`

The Occurrences tab of a bug page displays a table of recent occurrences. That table includes the class name, message, and time of occurrence for each exception. You can add your own columns to this table, if there is other important summary information that you wish to include. For example, the Rails client also adds host, controller, and action columns, and the iOS client adds device, OS version, and app version columns.

The mapping between client libraries and custom columns is `OccurrencesController::INDEX_FIELDS`.

### Update the Occurrence page header

By default, the title of the page is the uninformative "Occurrence of MyError". You can customize this; for example, a Rails error will have the title "MyError on app01.mycompany.com". You can add a more informative title for your client's exceptions by modifying the `occurrence_info` method in `app/views/occurrences/show.html.rb`.

Adding Your Own Data Fields
---------------------------

Any fields in your exception notification JSON that Squash does recognize, get added to the "user data" hash. If you want more specific behavior for a field, you can add native support for it in Squash. Check out the `square/squash` repository and make the following changes:

### Add the field to the `Occurrence` class

`Occurrence` uses a mixin called `HasMetadataColumn` that adds a schemaless, JSON-formatted column. Adding new fields is done by simply appending to the hash that is passed to the `has_metadata_column` call. See the other hash elements for examples. The `Occurrence` class documentation includes a comprehensive table of known fields; you can add to that as well.

The `Occurrence::NON_AGGREGATING_FIELDS` constant is a list of all fields that should not be available for the aggregation feature available on a bug's Occurrences tab. Any fields that are a) a continuous range of values, or b) of an unusual data type should be included in this list.

### Modify the views to include your fields

The occurrence info page is at `app/views/occurrences/show.html.rb`. It's Erector (yay, right?). Each tab view is a separate method in that class; the methods are invoked from the `occurrence_tabs` method. You can either append to an existing tab, or add a new tab entirely.

### Update the localization to include the field names

Even if English is the only language Squash is localized for, you still need to update the `config/locales/en.yml` file with the human-readable names for your new fields, as they are used in a few places throughout the website. The relevant key path is `activerecord.attributes.occurrence`.

More Information
----------------

Squash is extensively documented. Reading the documentation comments, or running `rake yard` in the Squash Web repository, will yield comprehensive docs. In particular, the `Occuurrence`, `Bug`, and `Blamer` class docs are very informative, as well as the README files for any of the Squash projects.
