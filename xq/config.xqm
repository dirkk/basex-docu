module namespace _ = "basex-docu-conversion-config";

(:~ absolute path to this project :)
declare variable $_:ABS-PATH := (static-base-uri() ! file:parent(.) ! file:parent(.));

(: PATHS on HDD :)

(:~ general tmp path :)
declare variable $_:TMP := "tmp/";

(:~ path to export db to :)
declare variable $_:EXPORT-PATH := $_:TMP || "basex-wiki-export/";

(:~ database name :)
declare variable $_:WIKI-DB := "basex-wiki";
(:~ List of Wiki Pages :)
declare variable $_:LS-PAGES := "list-of-wiki-pages.xml";
(:~ List of Wiki Images :)
declare variable $_:LS-IMAGES := "list-of-images.xml";

(:~ master docbook :)
declare variable $_:DOC-MASTER := "master-docbook.xml";
(:~ all-in-one master :)
declare variable $_:MASTER-ALL := "basex-full-documentation.xml";

(:~ Attributes to delete from 'no-render' item in $_:LS-PAGES :)
declare variable $_:NO-RENDER-DEL-ATTR := ("xml", "html", "docbook");

(:~ URI to WIKI :)
declare variable $_:WIKI-BASEURL := "http://docs.basex.org";

(:~ URI to MediaWiki API :)
declare variable $_:BX-API := $_:WIKI-BASEURL || "/api.php?";



(: PATHES in DB :)
(:~ Path to local exports :)
declare variable $_:WIKI-DUMP-PATH := "wikihtml/";

(:~ Path to Markdown output path:)
declare variable $_:MARKDOWN-PATH := "markdown/";

(:~ Path to images of local exports :)
declare variable $_:WIKI-DUMP-IMG := "wikiimg/";
declare variable $_:REL-PATH2IMG := "../" || $_:WIKI-DUMP-IMG;

(:~ Path to converted docbooks in db :)
declare variable $_:DOCBOOKS-PATH := "docbooks/";

(:~ use this wiki-page to declare how to group the items in the final docbook :)
declare variable $_:TOC-NAME := "Table of Contents";

(:~ List of pages to include to docbook :)
declare variable $_:PAGES-RELEVANT := _:open($_:LS-PAGES)//page[
  not(@title = $_:TOC-NAME) (: exclude Table of Contents from operations :)
  and @docbook (: exludes redirects :)
];

(:~
 : logs some text to a logfile
 :)
declare function _:log(
  $id as xs:string,
  $text as xs:string
) {
  file:append(
    $_:WIKI-DB || ".log", current-dateTime() || out:tab()
    || substring-after($id, "file:" || $_:ABS-PATH)
    || out:tab() || $text || out:nl()
  )
};
declare function _:logs(
  $id as xs:string,
  $texts as item()*
) {
  _:log($id, string-join( $texts ))
};


(:~
 : show proc:execute() stuff, in case of error remains silent otherwise
 :)
declare function _:execute(
  $cmd as xs:string,
  $args as xs:string*
) {
  let $res := proc:execute($cmd, $args)
  return
    if ($res/code = 0)
    then ()
    else ($cmd || " yields an error " || out:nl(), $res)
};

(:~
 : open document node - abbreviation
 : @param   $path document path in database $_:WIKI-DB
 : @return  corresponding document
 :)
declare
function _:open (
  $path as xs:string
) as document-node()* {
  db:open($_:WIKI-DB, $path)
};


(:~
 : finds out which version of BaseX the documentation is for
 :
 : @return  version number
 :)
declare function _:bx-version() as xs:string {
  _:open( $_:WIKI-DUMP-PATH || "Main%20Page.xml")//*:p/*:b
    ! substring-after(., "BaseX ")
};


(:~
 : open documents by name
 : for developing purpose only
 : @param   name
 : @return  document where path contains $name
 :)
declare function _:open-by-name (
  $name as xs:string
) as document-node()* {
  db:list($_:WIKI-DB)[contains(lower-case(.), lower-case($name))] ! _:open(.)
};


(:~
 : generates a string separated by : of certain items
 : located at given path
 : @param   $p path to look at
 : @param   $glob using glob syntax to match files
 : @return  colon separated path with items specified by $glob
 :)
declare function _:to-PATH(
  $p as xs:string,
  $glob as xs:string
) as xs:string {
  string-join(
    file:list($p, false(), $glob) ! ($p || '/' || .)
  , file:path-separator())
};


declare variable $_:NAVIGATION := map {
  "Getting Started": ("Main Page", "Getting Started", "Startup", "Command-Line Options", "Databases", "Commands", "DBA", "Database Server", "Graphical User Interface", "Parsers", "Standalone Mode", "Start Scripts", "Options"),
  "Modules": ("Module Library", "Admin Module", "Archive Module", "Array Module", "Binary Module", "CSV Module", "Client Module", "Conversion Module", "Cryptographic Module", "Database Module", "Fetch Module", "File Module", "Full-Text Module", "HTML Module", "HTTP Module", "Hashing Module", "Higher-Order Functions Module", "Index Module", "Inspection Module", "JSON Module", "Map Module", "Math Module", "Output Module", "Process Module", "Profiling Module", "RESTXQ Module", "Random Module", "Repository Module", "Request Module", "SQL Module", "Session Module", "Sessions Module", "Streaming Module", "Unit Module", "User Module", "Validation Module", "XQuery Module", "XSLT Module", "ZIP Module", "Geo Module"),
  "Developer": ("Clients", "Contribute", "Developing", "Developing with Eclipse", "Java Examples", "Java Bindings", "Maven", "Query Mode", "REST", "REST: POST Schema", "RESTXQ", "Server Protocol", "Server Protocol: Types", "Standard Mode", "Web Application", "Android", "Git", "Translations", "Open Issues", "Releases", "Integrating Eclipse", "Integrating oXygen", "Binary Data"),
  "WebDAV": ("WebDAV", "WebDAV: GNOME", "WebDAV: KDE", "WebDAV: Mac OSX", "WebDAV: Windows 7", "WebDAV: Windows XP"),
  "Internals": ("Advanced User's Guide", "Backups", "Catalog Resolver", "Configuration", "Execution Plan", "Index File Structure", "Indexes", "Logging", "Statistics", "Storage Layout", "Transaction Management", "Twitter", "User Management", "Repository", "Node Storage", "Events", "Shortcuts"),
  "XQuery": ("XQuery", "XQuery Recipes", "XQuery Errors", "XQuery 3.0", "XQuery 3.1", "XQuery Update", "XForms", "Full-Text", "Higher-Order Functions", "Serialization"),
  "DELETE": ("Community:Information", "Temp", "Documentation", "Security: Use Cases")
};
