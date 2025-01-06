#!/bin/awk -f

BEGIN {
    Debug = 0

    Title       = ""
    Published   = ""
    Updated     = ""
    Authors     = ""
    Auth        = ""
    Lead        = ""
    Article_img = ""
    Article     = ""
    Img         = ""
    Factbox     = ""
    Fb_title    = ""

    Is_reading_article   = 0
    Is_reading_body      = 0
    Is_reading_author    = 0
    Is_reading_ad        = 0
    Is_reading_embed     = 0
    Is_reading_img       = 0
    Is_reading_cap       = 0
    Is_reading_quote     = 0
    Is_reading_factbox   = 0
    Is_reading_slideshow = 0
    Slideshow_divs = 0
    Factbox_divs   = 0
}
{
    if ($0 ~ " *<article")
        Is_reading_article = 1

    if (Is_reading_article) {
        keyword = "data-seo-title"
        if ($0 ~ "<article .* " keyword) {
            Title = get_argument_value($0, keyword)
            if (Debug) print "Read title '" Title "'" > "/dev/stderr"
        }
        if ($0 ~ "<time class=\"time time--updated\"") {
            Updated = get_argument_value($0, "datetime")
            if (Debug) print "Read Updated '" Updated "'" > "/dev/stderr"
        }
        if ($0 ~ "<time class=\"time time--published\"") {
            Published = get_argument_value($0, "datetime")
            if (Debug) print "Read Published '" Published "'" > "/dev/stderr"
        }
        if ($0 ~ "<div class=\"article__lead") {
            Lead = $0
            sub(/ *<div class="article__lead[^>]*>/, "", Lead)
            sub(/<\/div>/, "", Lead)
            if (Debug) print "Read Lead '" Lead "'" > "/dev/stderr"
        }

        body = trim($0)
        if (body ~ "<div" && Is_reading_factbox) {
            Factbox_divs = Factbox_divs + 1
        }
        if (body ~ "</div>" && Is_reading_factbox) {
            Factbox_divs = Factbox_divs - 1
        }
        if (body ~ "<div class=\"ds-factbox\">") {
            if (Debug) print "Is reading Factbox" > "/dev/stderr"
            Is_reading_factbox  = 1
            Factbox_divs = Factbox_divs + 1
            body = ""
        } else if (body ~ "</div>" && Is_reading_factbox && Factbox_divs == 0) {
            if (Debug) print "No longer reading Factbox" > "/dev/stderr"
            Is_reading_factbox  = 0
            body = Factbox
        } else if (body ~ "<h2" && Is_reading_factbox) {
            sub(/ *<h2 class="ds-factbox__title">/, "", body)
            sub(/<\/h2>/, "", body)
            sub(/ *<span[^>]*>/, "", body)
            sub(/<\/span>/, " ", body)
            Fb_title = body
            body = ""
            if (Debug) print "Read Fb_title" Fb_title > "/dev/stderr"
        } else if (body ~ "<div class=\"ds-factbox__body\">" && Is_reading_factbox) {
            sub(/ *<div class="ds-factbox__body">/, "", body)
            sub(/<\/div>/, "", body)

            delim = "\n"
            if (Factbox == "") {
                Factbox = "\n| " Fb_title " |\n| "
                for (c = length(Fb_title); c > 0; c--)
                    Factbox = Factbox "-"
                Factbox = Factbox " |"
            }
            gsub(/<p>/, "| ", body)
            gsub(/<\/p>/, " |\n", body)
            Factbox = Factbox delim body
            body = ""
            if (Debug) print "Read Factbox: '" Factbox "'" > "/dev/stderr"
        } else if (Is_reading_factbox) {
            if (Debug) print "Is reading Factbox" > "/dev/stderr"
            body = ""
        }

        if (body ~ "<ul class=\"bylines__list\">") {
            if (Debug) print "Is reading author" > "/dev/stderr"
            Is_reading_author = 1
            body = ""

        } else if (body ~ "<span class=\"ds-list-item__title" && Is_reading_author) {
            sub(/<span class="ds-list-item__title[^>]*>/, "", body)
            sub(/<\/span>/, "", body)
            Auth = body
            body = ""
            if (Debug) print "Read Author name: '" Auth "'" > "/dev/stderr"

        } else if (body ~ "<span class=\"ds-list-item__subtitle" && Is_reading_author) {
            sub(/<span class="ds-list-item__subtitle[^>]*>/, "", body)
            sub(/<\/span>/, "", body)
            Auth = Auth " (" body ")"
            body = ""
            if (Debug) print "Read Author with title: '" Auth "'" > "/dev/stderr"

        } else if (body ~ "</li>" && Is_reading_author) {
            body = ""
            delim = (Authors != "") ? ", " : ""
            Authors = Authors delim Auth
            if (Debug) print "Read Author. Authors: '" Authors "'" > "/dev/stderr"
        } else if (body ~ "</ul>" && Is_reading_author) {
            Is_reading_author = 0
            if (Debug) print "No longer reading authors. Authors: '" Authors "'" > "/dev/stderr"
        }

        if (body ~ "<blockquote " && !Is_reading_embed) {
            if (Debug) print "Is reading quote" > "/dev/stderr"
            Is_reading_quote = 1
            body = ""
        } else if (body ~ "<span class=\"ds-quote__border\"></span>" && Is_reading_quote) {
            if (Debug) print "Is continuing to read quote" > "/dev/stderr"
            body = ""
        } else if (body ~ "</blockquote>") {
            if (Debug) print "No longer reading quote" > "/dev/stderr"
            Is_reading_quote = 0
            body = ""
        } else if (body != "" && Is_reading_quote) {
            if (Debug) print "Putting '> ' in front of body" > "/dev/stderr"
            body = "> *" body "*"
        }

        if (body ~ "<div class=\"article__body\"") {
            if (Debug) print "Is reading body" > "/dev/stderr"
            Is_reading_body = 1
            body = ""
        }
        if (body ~ "<footer class=\"article__footer\"") {
            if (Debug) print "No longer reading body or article" > "/dev/stderr"
            Is_reading_body = 0
            Is_reading_article = 0
        }

        if (body ~ "<div class=\"ad") {
            if (Debug) print "Is reading ad" > "/dev/stderr"
            Is_reading_ad = 1
            body = ""
        }
        if (body == "</div>" && Is_reading_ad) {
            if (Debug) print "No longer reading ad" > "/dev/stderr"
            Is_reading_ad = 0
            body = ""
        }
        if (body ~ "<div class=\"embed-widget") {
            if (Debug) print "Is reading embed" > "/dev/stderr"
            Is_reading_embed = 1
            body = ""
        } else if (body ~ "</div>" && Is_reading_embed) {
            if (Debug) print "No longer reading embed" > "/dev/stderr"
            Is_reading_embed = 0
            body = ""
        }

        if (Is_reading_slideshow) {
            if (Debug) print "Resetting Is_reading_img, Is_reading_cap" > "/dev/stderr"
            Is_reading_img = 0
            Is_reading_cap = 0
        }
        if (body ~ "<div" && Is_reading_slideshow) {
            Slideshow_divs = Slideshow_divs + 1
            if (Debug) print "Slideshow_divs: " Slideshow_divs > "/dev/stderr"
        }
        if (body ~ "</div" && Is_reading_slideshow) {
            Slideshow_divs = Slideshow_divs - 1
            if (Debug) print "Slideshow_divs: " Slideshow_divs > "/dev/stderr"
        }

        if (body ~ "<div class=\"slideshow " || body ~ "<div class=\"slideshow\">") {
            if (Debug) print "Is reading slideshow" > "/dev/stderr"
            Is_reading_slideshow = 1
            Slideshow_divs = Slideshow_divs + 1
            body = ""
        } else if (body ~ "<i class=\"ds-icon ds-icon--arrow_forward\">" && Is_reading_slideshow) {
            if (Debug) print "Is closing slideshow" > "/dev/stderr"
            is_closing_slideshow = 1
            body = ""
        } else if (body ~ "</div>" && Is_reading_slideshow && Slideshow_divs == 0) {
            if (Debug) print "No longer reading slideshow" > "/dev/stderr"
            Is_reading_slideshow = 0
            body = ""
        } else if (body ~ "<span class=\"ds-article-image__credits\">" && Is_reading_slideshow) {
            if (Debug) print "Is reading cred" > "/dev/stderr"
            Is_reading_cap = 1
        } else if (body ~ "<figcaption class=\"ds-image-caption slideshow__caption\">" && Is_reading_slideshow) {
            if (Debug) print "Is reading cap" > "/dev/stderr"
            Is_reading_cap = 1
            body = ""
        } else if (body ~ "<div class=\"graphic__source\">" && Is_reading_img) {
            if (Debug) print "Is reading graphic source" > "/dev/stderr"
            Is_reading_cap = 1
            body = ""
        } else if (body ~ "<img" && Is_reading_slideshow) {
            if (Debug) print "Is reading img in slideshow" > "/dev/stderr"
            Is_reading_img = 1
        } else if (body !~ "</figure" && Is_reading_slideshow) {
            if (Debug) print "Is reading slideshow and skipping line" > "/dev/stderr"
            body = ""
        }

        if (body ~ "<figure class=\"ds-article-image" || body ~ "<figure class=\"single-graphic\">" || (body ~ "<figure class=\"slideshow__figure\">" && Is_reading_slideshow)) {
            if (Debug) print "Is reading img" > "/dev/stderr"
            Is_reading_img = 1
            body = ""
        }
        if (body ~ "<img " && Is_reading_img) {
            src  = get_argument_value(body, "src")
            pos  = index(src, "?")
            if (pos != 0) {
                src  = substr(src, 0, pos - 1)
            } else {
                if (Debug) print "Warning: Image src does not contain \"?\", which is unusual. src: '" src "'" > "/dev/stderr"
            }
            print src >> "imgs"
            gsub(/[\/:]/, "_", src)

            Img  = "<img src=\"" src "\""
            body = ""
            if (Debug) print "Is reading Img: '" Img "'" > "/dev/stderr"
        }
        if ((body ~ "<div class=\"picture" || body ~ "<div class=\"single-graphic__inner\">" || body ~ "<div class=\"ds-full-width-element" || body ~ "</div>") && Is_reading_img) {
            if (Debug) print "Is reading img, skipping line" > "/dev/stderr"
            body = ""
        }
        if (body ~ "<figcaption" && Is_reading_img) {
            if (Debug) print "Is reading cap" > "/dev/stderr"
            Is_reading_cap = 1
            body = ""
        }
        if (body ~ "</figcaption>" && Is_reading_img) {
            if (Debug) print "No longer reading cap" > "/dev/stderr"
            Is_reading_cap = 0
            body = ""
        }
        if (body ~ "<span>" && Is_reading_cap) {
            body = substr(body, index(body, ">") + 1)
            body = substr(body, 0, index(body, "<") - 1)
            body = trim(body)
            Img  = Img " caption=\"" body "\""
            body = ""
            if (Debug) print "Is reading caption, Img: '" Img "'" > "/dev/stderr"
        }
        if (body ~ "<span class=\"ds-article-image__credits" && Is_reading_cap) {
            body = substr(body, index(body, ">") + 1)
            body = substr(body, 0, index(body, "<") - 1)
            body = trim(body)
            Img  = Img " credits=\"" body "\""
            body = ""
            if (Debug) print "Is reading cred, Img: '" Img "'" > "/dev/stderr"
        }
        if (body ~ "</div>" && Is_reading_cap) {
            Is_reading_cap = 0
            body = ""
            if (Debug) print "No longer reading cap" > "/dev/stderr"
        }
        if (body != "" && Is_reading_cap) {
            body = trim(body)
            Img  = Img " credits=\"" body "\""
            body = ""
            if (Debug) print "Is reading cred, Img: '" Img "'" > "/dev/stderr"
        }
        if (body ~ "</figure>") {
            Is_reading_img = 0
            Img  = Img " />"
            caption = get_argument_value(Img, "caption")
            if (caption != "")
                caption = " \"" caption "\""
            body = "![" get_argument_value(Img, "credits") "](" get_argument_value(Img, "src") caption ")"
            if (body != "![]()" && !Is_reading_body)
                Article_img = Article_img "\n" body "\n"
            if (Debug) print "Read figure '" body "', Article_img '" Article_img "'" > "/dev/stderr"
        }

        if (body ~ "<div class=\"ds-thematic-break\"><hr></div>") {
            if (Debug) print "Substituting thematic break" > "/dev/stderr"
            body = "***"
        }

        if (Is_reading_body && !Is_reading_ad && !Is_reading_embed && body != "" && body != "</div>") {
            if (Debug) print "Appending into Article" > "/dev/stderr"
            Article = Article "\n" transform_hyperlink(body)
        }
    }

    if ($0 ~ " *</article")
        Is_reading_article = 0
}
END {
    post_process()

    print "# " Title
    times = "Publicerad: " transform_timestamp(Published)
    if (Updated != "")
        times = times ". Uppdaterad: " transform_timestamp(Updated)
    print ""
    if (Authors == "")
        Authors = "-"
    print "Av: " Authors
    print times
    print Article_img
    print "***"
    print Lead
    print "***"
    print Article
}

function transform_timestamp(time,  pos) {
    sub(/T/, " ", time)
    pos = index(time, ".")
    return substr(time, 0, pos - 1)
}

function transform_hyperlink(text,  tmp, pos_s, pos_c, pos_e, url) {
    while (1) {
        if (text !~ ".*<a ")
            return text
        pos_s = index(text, "<a href=")
        tmp   = substr(text, pos_s)
        pos_c = index(tmp, ">")
        url   = get_argument_value(tmp, "href")
        if (url !~ ".*http")
            url = "https://www.dn.se" url
        pos_e = index(tmp, "</a>")
        text  = substr(text, 0, pos_s - 1) "[" substr(tmp, pos_c + 1, pos_e - pos_c - 1) "](" url ")" substr(tmp, pos_e + 4)
    }
}

function post_process() {
    Lead = transform_hyperlink(Lead)
    Lead = html_to_commonmark(Lead)
    Article = html_to_commonmark(Article)
}
function html_to_commonmark(text) {
    text = gensub(/\n *<h2>([^\n]*)<\/h2> *\n/,  "\n## \\1\n", "g", text)
    text = gensub(/\n *<h3>([^\n]*)<\/h3> *\n/, "\n### \\1\n", "g", text)
    gsub(/<br>/, "\n", text)
    gsub(/<p class="[a-zA-Z0-9\-_]*">/, "\n", text)
    gsub(/<p>/, "\n", text)
    gsub(/<\/p>/, "\n", text)
    gsub(/ ?<em> ?/, " *", text)
    gsub(/<\/em>/, "*", text)
    gsub(/ ?<i> ?/, " *", text)
    gsub(/<\/i>/, "*", text)
    gsub(/ ?<strong> ?/, " **", text)
    gsub(/<\/strong>/, "**", text)
    gsub(/\n +/, "\n", text)
    gsub(/&nbsp;/, " ", text)
    return text
}

function get_argument_value(text, argument,  pos) {
    argument = argument "="
    pos = index(text, argument)
    if (pos == 0)
        return ""
    text = substr(text, pos + length(argument) + 1)
    pos  = index (text, "\"")
    return substr(text, 0, pos - 1)
}

# Trims away any whitespace (i.e. space, tab, newlines, carrige-returns) from the left and right of given [string]
function trim(string) {
    sub(/^[ \t\r\n]+/,  "", string)
    sub( /[ \t\r\n]+$/, "", string)
    return string
}
