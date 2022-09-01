#!/bin/awk -f

BEGIN {
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
    is_reading_img_cap   = 0;
    is_reading_img_cred  = 0;
    is_reading_quote     = 0;
    is_reading_factbox   = 0;
    is_reading_fb_title  = 0;
    is_reading_fb_cont   = 0;
    is_reading_slideshow = 0;
    is_closing_slideshow = 0;
}
{
    if ($0 ~ " *<article")
        is_reading_article = 1;

    if (is_reading_article) {
        keyword = "data-seo-title";
        if ($0 ~ "<article .* " keyword)
            title = get_argument_value($0, keyword);
        if ($0 ~ "<time class=\"time time--updated\"")
            updated = get_argument_value($0, "datetime");
        if ($0 ~ "<time class=\"time time--published\"")
            published = get_argument_value($0, "datetime");
        if ($0 ~ "<div class=\"article__lead\">") {
            lead = $0;
            sub(/ *<div class="article__lead">/, "", lead);
            sub(/<\/div>/, "", lead);
        }

        body = trim($0);
        if (body ~ "<aside class=\"fact-box") {
            is_reading_factbox  = 1;
            body = "";
        } else if (body ~ "</aside>") {
            is_reading_factbox  = 0;
            body = factbox;
        } else if (body ~ "<div class=\"fact-box__container\">") {
            is_reading_fb_cont  = 1;
            body = "";
        } else if (body ~ "<h2>" && is_reading_fb_cont) {
            is_reading_fb_title = 1;
            body = "";
        } else if (body ~ "</h2>" && is_reading_fb_title) {
            is_reading_fb_title = 0;
            body = "";
        } else if (is_reading_fb_title) {
            fb_title = fb_title body;
            body = "";
        } else if (body ~ "</div>" && is_reading_fb_cont) {
            is_reading_fb_cont = 0;
            body = "";
        } else if (is_reading_fb_cont) {
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
        } else if (is_reading_factbox)
            body = "";

        if (body ~ "<div class=\"author__info\">") {
            is_reading_author = 1;

        } else if (body ~ "<a class=\"author__name\"" && is_reading_author) {
            auth = transform_hyperlink(body);
            body = "";

        } else if (body ~ "<span class=\"author__role\">" && is_reading_author) {
            role = substr(body, index(body, ">") + 1);
            auth = auth " (" substr(role, 0, index(role, "</span>") - 1) ")";
            body = "";

        } else if (body ~ "</div>" && is_reading_author) {
            is_reading_author = 0;
            body = "";
            delim = (authors != "") ? ", " : "";
            authors = authors delim auth;
        }

        if (body ~ "<blockquote " && !is_reading_embed) {
            is_reading_quote = 1;
            body = "";
        } else if (body ~ "<div class=" && is_reading_quote) {
            body = "";
        } else if (body ~ "</blockquote>") {
            is_reading_quote = 0;
            body = "";
        } else if (body != "" && is_reading_quote) {
            body = "> " body;
        }

        if (body ~ "<div class=\"article__body\">") {
            is_reading_body = 1;
            body = "";
        }
        if (body ~ "<footer class=\"article__footer\">") {
            is_reading_body = 0;
            is_reading_article = 0;
        }

        if (body ~ "<div class=\"ad") {
            is_reading_ad = 1;
            body = "";
        }
        if (body == "</div>" && is_reading_ad) {
            is_reading_ad = 0;
            body = "";
        }
        if (body ~ "<div class=\"embed-widget") {
            is_reading_embed = 1;
            body = "";
        } else if (body ~ "</div>" && is_reading_embed) {
            is_reading_embed = 0;
            body = "";
        }

        if (is_reading_slideshow) {
            is_reading_img  = 0;
            is_reading_cap  = 0;
            is_reading_cred = 0;
        }
        if (body ~ "<div class=\"slideshow ") {
            is_reading_slideshow = 1;
            body = "";
        } else if (body ~ "<use xlink:href=\"#slideshow-arrow-next\">" && is_reading_slideshow) {
            is_closing_slideshow = 1;
            body = "";
        } else if (body ~ "</div>" && is_closing_slideshow) {
            is_reading_slideshow = 0;
            is_closing_slideshow = 0;
            body = "";
        } else if (body ~ "<div class=\"slideshow__image-author\">" && is_reading_slideshow) {
            is_reading_cred = 1;
            body = substr(body, index(body, ">") + 1);
            body = substr(body, 0, index(body, "<") - 1);
        } else if (body ~ "<span class=\"slideshow__caption-text\"" && is_reading_slideshow) {
            is_reading_cap = 1;
        } else if (body ~ "<img" && is_reading_slideshow) {
            is_reading_img = 1;
        } else if (body !~ "</figure" && is_reading_slideshow)
            body = "";

        if (body ~ "<figure class=\"article__img" || (body ~ "<figure class=\"slideshow__figure\">" && is_reading_slideshow)) {
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
        }
        if ((body ~ "<div class=\"picture" || body ~ "</div>") && is_reading_img)
            body = "";
        if (body ~ "<figcaption" && is_reading_img) {
            is_reading_cap = 1;
            body = "";
        }
        if (body ~ "</figcaption>" && is_reading_img) {
            is_reading_cap = 0;
            body = "";
        }
        if (body ~ "<span class=\"article__img-credits\">" && is_reading_cap) {
            is_reading_cred = 1;
            body = "";
        }
        if (body ~ "</span>" && is_reading_cred) {
            is_reading_cred = 0;
            body = "";
        }
        if (body ~ "</figure>") {
            is_reading_img = 0;
            img  = img " />";
            caption = get_argument_value(img, "caption");
            if (caption != "")
                caption = " \"" caption "\"";
            body = "![" get_argument_value(img, "credits") "](" get_argument_value(img, "src") caption ")";
            if (article_img == "" && body != "![]()" && !is_reading_body)
                article_img = body;
        }

        if (is_reading_cred && body != "") {
            img  = img " credits=\"" body "\"";
            body = "";
        } else if (is_reading_cap && body != "") {
            pos  = index(body, ">");
            if (pos > 0) { #Assume this means the text is wrapped in html
                body = substr(body, pos + 1);
                body = substr(body, 0, index(body, "<") - 1);
            }
            img  = img " caption=\"" body "\"";
            body = "";
        }

        if (is_reading_body && !is_reading_ad && !is_reading_embed && body != "" && body != "</div>")
            article = article "\n" transform_hyperlink(body);
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
