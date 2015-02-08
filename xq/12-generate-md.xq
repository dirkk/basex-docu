(:~
 : Generate Markdown from docbook
 :)
import module namespace C = "basex-docu-conversion-config" at "config.xqm";

declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace docbook = "http://docbook.org/ns/docbook";
declare default element namespace "http://docbook.org/ns/docbook";

declare function local:get-lines($string as xs:string?) as xs:string* {
  for $line in tokenize($string, "\n")
  return if (string-length(normalize-space($line)) = 0) then () else $line
};

declare function local:decode($string as xs:string?) as xs:string* {
  let $converter := map {
    '&lt;': '<',
    '&gt;': '>'
  }
  return fold-left(map:keys($converter), $string, function($result, $key) {
    let $value := map:get($converter, $key)
    return replace($result, $key, $value)
  })
};

declare function local:code-signature($el as element()) as xs:string {
  let $text := function($el as item()*) { string-join(($el/node()) ! local:transform(., 1)) }
  let $signatures := string-join(($el//row[entry[1]/para/emphasis = "Signatures"]/entry[2]/para/node()) ! local:transform(., 1), out:nl())
  let $summary := $text($el//row[entry[1]/para/emphasis = "Summary"]/entry[2]/para)
  let $examples:= $text($el//row[entry[1]/para/emphasis = "Examples"]/entry[2]/para)
  let $errors := $text($el//row[entry[1]/para/emphasis = "Errors"]/entry[2]/para)
  return out:nl() || $signatures || out:nl() || out:nl() ||
    $summary || out:nl() || out:nl() ||
    (if ($errors) then ("**Errors**" || out:nl() || out:nl() || $errors || out:nl()) else ()) ||
    (if ($examples) then ("**Examples**" || out:nl() || out:nl() || $examples || out:nl()) else ())
};

declare function local:table($el as element()) as xs:string {
  let $headers :=
    for $entry in $el//row[1]/entry
    return string-join(
      ($entry/para/node()) ! local:transform(., 1)
    , "")
  return out:nl() || string-join($headers, " | ") || out:nl() ||
    string-join($headers ! local:underline(., "-"), " | ") || out:nl() || string-join(
      for $line in $el//row[position() > 1]
      let $c :=
        for $entry in $line/entry
        return string-join(
          ($entry/para/node()) ! local:transform(., 1)
        , "")
      return string-join($c, " | ") || out:nl()
    )
};

declare function local:to-url($el as element()) as xs:string {
  let $target := C:open($C:DOCBOOKS-PATH)/chapter[//anchor[@*:id = $el/@linkend]]/title/string()
  return 
    if (empty($target) or $target = "")
    then 
      let $page := C:open($C:DOCBOOKS-PATH)/chapter[@*:id = $el/@linkend]/title/string()
      return $page || ".md"
    else $target || ".md#" || $el/@linkend/string()
};

declare function local:left-trim($string as xs:string?) as xs:string {
  replace($string, '^\s+', '')
};

declare function local:underline($string as xs:string, $repl as xs:string) {
  string-join((1 to string-length($string)) ! $repl, "")
};

declare function local:get-image($element as element(inlinemediaobject)) {
  let $alt := substring($element/imageobject[not(@role = "html")]/imagedata/@fileref/string(), 12)
  let $path := "img/" || $alt
  return "![" || $alt || "](" || $path || ")" 
};

declare function local:transform($element as item(), $level as xs:integer) as xs:string {
  if (($element instance of xs:string) or ($element instance of text()) or empty($element))
  then 
    if (string-length(local:left-trim($element)) = 0) then "" else xs:string($element)
  else
  let $name := name($element)
  let $text := function($el as item()*, $level as xs:integer) { string-join(($el/node()) ! local:transform(., $level), "") }
  return
    switch ($name)
      case "link" return 
        if ($element/inlinemediaobject) then
          (: Images should not be linked for enlargement in markdown :)
          $element/inlinemediaobject ! local:get-image(.)
        else if ($element/@xlink:href)
          (: external link :)
          then 
            if ($element/string() = "Read this entry online in the BaseX Wiki.")
            then ""
            else "[" || $element || "](" || $element/@xlink:href || ")"
          (: internal link :)
          else "[" || $element || "](" || local:to-url($element) || ")"
      case "title" return
        let $child-content := string-join(($element/node()) ! local:transform(., $level), "")
(:
        let $section := switch ($level) case 1 return "=" case 2 return "-" default return "-"
        return $child-content || out:nl() || local:underline($element, $section) || out:nl()
:)
        return out:nl() || string-join((1 to $level) ! "#") || " " || local:left-trim($child-content) || out:nl()
      case "para" return out:nl() || $text($element, $level) || out:nl() || out:nl()
      case "anchor" return $text($element, $level)
      case "literal" return "`" || $text($element, $level) || "`"
      case "emphasis" return 
        switch($element/@role)
          case "italic" return "_" || $text($element, $level) || "_"
          case "bold" return "**" || $text($element, $level) || "**"
          default return $text($element, $level)
      case "screen" return
        let $code := 
          for $line in local:get-lines($element)
          return "    " || local:decode($line) || out:nl()
        return out:nl() || string-join($code) || out:nl()
      case "orderedlist" return string-join(
        for $item at $pos in $element/listitem/para
        return $pos || ". " || local:left-trim($text($item, $level)) || out:nl()
      , "")
      case "itemizedlist" return string-join(
        for $item in $element/listitem/para
        return " * " || local:left-trim($text($item, $level)) || out:nl()
      , "")
      case "section" return $text($element, $level + 1)
      case "informaltable" return
        if ($element//emphasis = "Signatures" and $element//emphasis = "Summary")
        then local:code-signature($element)
        else local:table($element)
      default return "UNKNOWN"
};
(: Clean previous build :)
file:delete($C:EXPORT-PATH || $C:MARKDOWN-PATH, true()),
file:create-dir($C:EXPORT-PATH || $C:MARKDOWN-PATH),
file:create-dir($C:EXPORT-PATH || $C:MARKDOWN-PATH || "docs/"),
file:create-dir($C:EXPORT-PATH || $C:MARKDOWN-PATH || "docs/img"),
(: Copy image dir :)
for $f in file:list($C:EXPORT-PATH || "wikiimg")
return file:copy($C:EXPORT-PATH || "wikiimg/" || $f, $C:EXPORT-PATH || $C:MARKDOWN-PATH || "docs/img"),

(: Generate markdown :)
let $output-dir := $C:EXPORT-PATH || $C:MARKDOWN-PATH || "docs/"
for $chapter in C:open($C:DOCBOOKS-PATH)/chapter
let $title := $chapter/title/string()
let $output-path := $output-dir || $title || ".md"

let $content :=
  for $element in $chapter/*
  return local:transform($element, 1)
return file:write($output-path, $content, 
  <output:serialization-parameters>
    <output:method value='text'/>
  </output:serialization-parameters>
),

(: Generate config :)
let $output-config := $C:EXPORT-PATH || $C:MARKDOWN-PATH || "mkdocs.yml"
let $content :=
  "site_name: BaseX Documentation" || out:nl() ||
  "theme: readthedocs" || out:nl() ||
  "repo_url: https://github.com/dirkk/basex-rtd" || out:nl() ||
  "pages:" || out:nl() || string-join(
    for $chapter in map:keys($C:NAVIGATION)
    for $title in map:get($C:NAVIGATION, $chapter)
    return 
      '- ["' || $title || '.md", "' || $chapter || '", "' || $title || '"]' || out:nl()
  )
return file:write($output-config, $content)
