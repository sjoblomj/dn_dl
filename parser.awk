#!/bin/awk -f

BEGIN {
    debug = 0;

    title       = "";
    published   = "";
    updated     = "";
    authors     = "";
    auth        = "";
    lead        = "";
    article_img = "";
    article     = "";
    img         = "";
    factbox     = "";
    fb_title    = "";

    is_reading_article   = 0;
    is_reading_body      = 0;
    is_reading_author    = 0;
    is_reading_ad        = 0;
    is_reading_embed     = 0;
    is_reading_img       = 0;
    is_reading_cap       = 0;
    is_reading_quote     = 0;
    is_reading_factbox   = 0;
    is_reading_slideshow = 0;
    slideshow_divs = 0;
    factbox_divs   = 0;
}
{
    if ($0 ~ " *<article")
        is_reading_article = 1;

    if (is_reading_article) {
        keyword = "data-seo-title";
        if ($0 ~ "<article .* " keyword) {
            title = get_argument_value($0, keyword);
            if (debug) print "Read title '" title "'" > "/dev/stderr"
        }
        if ($0 ~ "<time class=\"time time--updated\"") {
            updated = get_argument_value($0, "datetime");
            if (debug) print "Read updated '" updated "'" > "/dev/stderr"
        }
        if ($0 ~ "<time class=\"time time--published\"") {
            published = get_argument_value($0, "datetime");
            if (debug) print "Read published '" published "'" > "/dev/stderr"
        }
        if ($0 ~ "<div class=\"article__lead\">") {
            lead = $0;
            sub(/ *<div class="article__lead">/, "", lead);
            sub(/<\/div>/, "", lead);
            if (debug) print "Read lead '" lead "'" > "/dev/stderr"
        }

        body = trim($0);
        if (body ~ "<div" && is_reading_factbox) {
            factbox_divs = factbox_divs + 1;
        }
        if (body ~ "</div>" && is_reading_factbox) {
            factbox_divs = factbox_divs - 1;
        }
        if (body ~ "<div class=\"ds-factbox\">") {
            if (debug) print "Is reading factbox" > "/dev/stderr"
            is_reading_factbox  = 1;
            factbox_divs = factbox_divs + 1;
            body = "";
        } else if (body ~ "</div>" && is_reading_factbox && factbox_divs == 0) {
            if (debug) print "No longer reading factbox" > "/dev/stderr"
            is_reading_factbox  = 0;
            body = factbox;
        } else if (body ~ "<h2" && is_reading_factbox) {
            sub(/ *<h2 class="ds-factbox__title">/, "", body);
            sub(/<\/h2>/, "", body);
            fb_title = body;
            body = "";
            if (debug) print "Read fb_title" fb_title > "/dev/stderr"
        } else if (body ~ "<div class=\"ds-factbox__body\">" && is_reading_factbox) {
            sub(/ *<div class="ds-factbox__body">/, "", body);
            sub(/<\/div>/, "", body);

            delim = "\n";
            if (factbox == "") {
                factbox = "| " fb_title " |\n| ";
                for (c = length(fb_title); c > 0; c--)
                    factbox = factbox "-";
                factbox = factbox " |";
            }
            gsub(/<p>/, "| ", body);
            gsub(/<\/p>/, " |\n", body);
            factbox = factbox delim body;
            body = "";
            if (debug) print "Read factbox: '" factbox "'" > "/dev/stderr"
        } else if (is_reading_factbox) {
            if (debug) print "Is reading factbox" > "/dev/stderr"
            body = "";
        }

        if (body ~ "<div class=\"ds-byline__titles\">") {
            if (debug) print "Is reading author" > "/dev/stderr"
            is_reading_author = 1;
            body = "";

        } else if (body ~ "<span class=\"ds-byline__title\">" && is_reading_author) {
            sub(/<span class="ds-byline__title">/, "", body);
            sub(/<\/span>/, "", body);
            auth = body;
            body = "";
            if (debug) print "Read author '" auth "'" > "/dev/stderr"

        } else if (body ~ "<span class=\"ds-byline__subtitle\">" && is_reading_author) {
            sub(/<span class="ds-byline__subtitle">/, "", body);
            sub(/<\/span>/, "", body);
            auth = auth " (" body ")";
            body = "";
            if (debug) print "Read author '" auth "'" > "/dev/stderr"

        } else if (body ~ "</div>" && is_reading_author) {
            is_reading_author = 0;
            body = "";
            delim = (authors != "") ? ", " : "";
            authors = authors delim auth;
            if (debug) print "No longer reading author. authors '" authors "'" > "/dev/stderr"
        }

        if (body ~ "<blockquote " && !is_reading_embed) {
            if (debug) print "Is reading quote" > "/dev/stderr"
            is_reading_quote = 1;
            body = "";
        } else if (body ~ "<span class=\"ds-quote__border\"></span>" && is_reading_quote) {
            if (debug) print "Is continuing to read quote" > "/dev/stderr"
            body = "";
        } else if (body ~ "</blockquote>") {
            if (debug) print "No longer reading quote" > "/dev/stderr"
            is_reading_quote = 0;
            body = "";
        } else if (body != "" && is_reading_quote) {
            if (debug) print "Putting '> ' in front of body" > "/dev/stderr"
            body = "> " body;
        }

        if (body ~ "<div class=\"article__body\">") {
            if (debug) print "Is reading body" > "/dev/stderr"
            is_reading_body = 1;
            body = "";
        }
        if (body ~ "<footer class=\"article__footer\">") {
            if (debug) print "No longer reading body or article" > "/dev/stderr"
            is_reading_body = 0;
            is_reading_article = 0;
        }

        if (body ~ "<div class=\"ad") {
            if (debug) print "Is reading ad" > "/dev/stderr"
            is_reading_ad = 1;
            body = "";
        }
        if (body == "</div>" && is_reading_ad) {
            if (debug) print "No longer reading ad" > "/dev/stderr"
            is_reading_ad = 0;
            body = "";
        }
        if (body ~ "<div class=\"embed-widget") {
            if (debug) print "Is reading embed" > "/dev/stderr"
            is_reading_embed = 1;
            body = "";
        } else if (body ~ "</div>" && is_reading_embed) {
            if (debug) print "No longer reading embed" > "/dev/stderr"
            is_reading_embed = 0;
            body = "";
        }

        if (is_reading_slideshow) {
            if (debug) print "Resetting is_reading_img, is_reading_cap" > "/dev/stderr"
            is_reading_img = 0;
            is_reading_cap = 0;
        }
        if (body ~ "<div" && is_reading_slideshow) {
            slideshow_divs = slideshow_divs + 1;
            if (debug) print "slideshow_divs: " slideshow_divs > "/dev/stderr"
        }
        if (body ~ "</div" && is_reading_slideshow) {
            slideshow_divs = slideshow_divs - 1;
            if (debug) print "slideshow_divs: " slideshow_divs > "/dev/stderr"
        }

        if (body ~ "<div class=\"slideshow " || body ~ "<div class=\"slideshow\">") {
            if (debug) print "Is reading slideshow" > "/dev/stderr"
            is_reading_slideshow = 1;
            slideshow_divs = slideshow_divs + 1;
            body = "";
        } else if (body ~ "<i class=\"ds-icon ds-icon--arrow_forward\">" && is_reading_slideshow) {
            if (debug) print "Is closing slideshow" > "/dev/stderr"
            is_closing_slideshow = 1;
            body = "";
        } else if (body ~ "</div>" && is_reading_slideshow && slideshow_divs == 0) {
            if (debug) print "No longer reading slideshow" > "/dev/stderr"
            is_reading_slideshow = 0;
            body = "";
        } else if (body ~ "<span class=\"ds-article-image__credits\">" && is_reading_slideshow) {
            if (debug) print "Is reading cred" > "/dev/stderr"
            is_reading_cap = 1;
        } else if (body ~ "<figcaption class=\"ds-image-caption slideshow__caption\">" && is_reading_slideshow) {
            if (debug) print "Is reading cap" > "/dev/stderr"
            is_reading_cap = 1;
            body = "";
        } else if (body ~ "<img" && is_reading_slideshow) {
            if (debug) print "Is reading img" > "/dev/stderr"
            is_reading_img = 1;
        } else if (body !~ "</figure" && is_reading_slideshow) {
            if (debug) print "Is reading slideshow and skipping line" > "/dev/stderr"
            body = "";
        }

        if (body ~ "<figure class=\"ds-article-image" || (body ~ "<figure class=\"slideshow__figure\">" && is_reading_slideshow)) {
            if (debug) print "Is reading img" > "/dev/stderr"
            is_reading_img = 1;
            body = "";
        }
        if (body ~ "<img " && is_reading_img) {
            src  = get_argument_value(body, "src");
            pos  = index(src, "?");
            src  = substr(src, 0, pos - 1);
            print src >> "imgs";
            gsub(/[\/:]/, "_", src);

            img  = "<img src=\"" src "\"";
            body = "";
            if (debug) print "Is reading img: '" img "'" > "/dev/stderr"
        }
        if ((body ~ "<div class=\"picture" || body ~ "<div class=\"ds-full-width-element\">" || body ~ "</div>") && is_reading_img) {
            if (debug) print "Is reading img, skipping line" > "/dev/stderr"
            body = "";
        }
        if (body ~ "<figcaption" && is_reading_img) {
            if (debug) print "Is reading cap" > "/dev/stderr"
            is_reading_cap = 1;
            body = "";
        }
        if (body ~ "</figcaption>" && is_reading_img) {
            if (debug) print "No longer reading cap" > "/dev/stderr"
            is_reading_cap = 0;
            body = "";
        }
        if (body ~ "<span aria-hidden=\"true\">" && is_reading_cap) {
            body = substr(body, index(body, ">") + 1);
            body = substr(body, 0, index(body, "<") - 1);
            img  = img " caption=\"" body "\"";
            body = "";
            if (debug) print "Is reading caption, img: '" img "'" > "/dev/stderr"
        }
        if (body ~ "<span class=\"ds-article-image__credits\">" && is_reading_cap) {
            body = substr(body, index(body, ">") + 1);
            body = substr(body, 0, index(body, "<") - 1);
            img  = img " credits=\"" body "\"";
            body = "";
            if (debug) print "Is reading cred, img: '" img "'" > "/dev/stderr"
        }
        if (body ~ "</figure>") {
            is_reading_img = 0;
            img  = img " />";
            caption = get_argument_value(img, "caption");
            if (caption != "")
                caption = " \"" caption "\"";
            body = "![" get_argument_value(img, "credits") "](" get_argument_value(img, "src") caption ")";
            if (body != "![]()" && !is_reading_body)
                article_img = article_img "\n" body;
            if (debug) print "Read figure '" body "', article_img '" article_img "'" > "/dev/stderr"
        }

        if (body ~ "<div class=\"ds-thematic-break\"><hr></div>") {
            if (debug) print "Substituting thematic break" > "/dev/stderr"
            body = "***"
        }

        if (is_reading_body && !is_reading_ad && !is_reading_embed && body != "" && body != "</div>") {
            if (debug) print "Appending into article" > "/dev/stderr"
            article = article "\n" transform_hyperlink(body);
        }
    }

    if ($0 ~ " *</article")
        is_reading_article = 0;
}
END {
    post_process();

    print "# " title;
    times = "Publicerad: " transform_timestamp(published);
    if (updated != "")
        times = times ". Uppdaterad: " transform_timestamp(updated);
    print "";
    if (authors == "")
        authors = "-";
    print "Av: " authors;
    print times;
    print article_img;
    print "***";
    print lead;
    print "***";
    print article;
}

function transform_timestamp(time,  pos) {
    sub(/T/, " ", time);
    pos = index(time, ".");
    return substr(time, 0, pos - 1);
}

function transform_hyperlink(text,  tmp, pos_s, pos_c, pos_e, url) {
    while (1) {
        if (text !~ ".*<a ")
            return text;
        pos_s = index(text, "<a href=");
        tmp   = substr(text, pos_s);
        pos_c = index(tmp, ">");
        url   = get_argument_value(tmp, "href");
        if (url !~ ".*http")
            url = "https://www.dn.se" url;
        pos_e = index(tmp, "</a>");
        text  = substr(text, 0, pos_s - 1) "[" substr(tmp, pos_c + 1, pos_e - pos_c - 1) "](" url ")" substr(tmp, pos_e + 4);
    }
}

function post_process() {
    lead = html_to_commonmark(lead);
    article = html_to_commonmark(article);
}
function html_to_commonmark(text) {
    text = gensub(/\n *<h2>([^\n]*)<\/h2> *\n/,  "\n## \\1\n", "g", text);
    text = gensub(/\n *<h3>([^\n]*)<\/h3> *\n/, "\n### \\1\n", "g", text);
    gsub(/<br>/, "\n", text);
    gsub(/<p class="[a-zA-Z0-9\-_]*">/, "\n", text);
    gsub(/<p>/, "\n", text);
    gsub(/<\/p>/, "\n", text);
    gsub(/ ?<em> ?/, " *", text);
    gsub(/<\/em>/, "*", text);
    gsub(/ ?<strong> ?/, " **", text);
    gsub(/<\/strong>/, "**", text);
    gsub(/\n +/, "\n", text);
    return text;
}

function get_argument_value(text, argument,  pos) {
    argument = argument "=";
    pos  = index (text, argument);
    if (pos == 0)
        return "";
    text = substr(text, pos + length(argument) + 1);
    pos  = index (text, "\"");
    return substr(text, 0, pos - 1);
}

# Trims away any whitespace (i.e. space, tab, newlines, carrige-returns) from the left and right of given [string]
function trim(string) {
    sub(/^[ \t\r\n]+/,  "", string);
    sub( /[ \t\r\n]+$/, "", string);
    return string;
}
