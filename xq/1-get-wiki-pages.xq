(:~
 : Load Pages from BaseX MediaWiki into Database
 : at path $_:WIKI-DUMP-PATH.
 : extract redirects immediately
 :)
import module namespace C = "basex-docu-conversion-config" at "config.xqm";
declare option db:chop "false";

let $limit := 500, (: no of pages to retreive :)
    $uri := $C:BX-API || "action=query&amp;list=allpages&amp;aplimit=" || $limit || "&amp;format=xml"
for $page in C:open($C:LS-PAGES)//page

(: request page content :)
let $req :=
  http:send-request(
    <http:request method="get" />,
    $C:BX-API || "action=parse&amp;format=xml&amp;page=" || $page/@title-enc || "&amp;prop=text|images|displaytitle|links|externallinks"
  )[2]
  
(: parse html :)
let $contents := $req/api/parse/text/text()/string()
  ! ((# db:parser "html" #){
    fn:parse-xml("<_>" || . ||"</_>")
  })/node()/node()

(: check if redirect or real page :)
return if (starts-with(($contents/*/text())[1], "REDIRECT"))
then (
  (: change redirect attributes and so :)
  replace value of node $page/@redirect
          with $contents/*/*/text()[1],
  replace value of node $page/@no-render
          with "no-render",
  delete node $page/@*[name() = $C:NO-RENDER-DEL-ATTR]
)
(: add page (no redirection) :)
else db:add(
  $C:WIKI-DB,
  <html><head><title>{$page/@title/data()}</title></head><body>{$contents}</body></html>,
  $page/@xml
),

db:output(
  C:logs(("loaded all wiki pages to ", $C:WIKI-DB, " at path ", $C:WIKI-DUMP-PATH, "; added flag for 'redirect' pages"))
)