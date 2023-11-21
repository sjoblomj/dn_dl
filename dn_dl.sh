#!/bin/bash

first_year=1864
dn_address="" # "https://www.dn.se/av/andrev-walden/"
page_title="" # "Andrev Walden"
cookie=""
download="n"
use_smaller_images_if_better="n"
preserve_img_quality="n"
divide_by_year="n"
format="pdf"
output_dir=""
mark2epub_dir=""

print_help() {
    echo "dn_dl 3.2 by Johan Sjöblom"
    echo "Parses and downloads articles from the Swedish"
    echo "newspaper Dagens Nyheter. Can output into Markdown,"
    echo "PDF or EPUB."
    echo ""
    echo "Parameters:"
    echo "  --url \"URL\""
    echo "    Mandatory param. URL to download from."
    echo ""
    echo "  --cookie \"COOKIE\""
    echo "    Mandatory param. The Request Header Cookie that"
    echo "    your browser uses to access dn.se"
    echo ""
    echo "  --invalidate-cache"
    echo "    Optional param. Download articles, even if they"
    echo "    have been downloaded previously."
    echo ""
    echo "  --use-smaller-images-if-better-for-pdf"
    echo "    Optional param. Attempt to downsize images"
    echo "    somewhat in the PDF, if that results in fewer"
    echo "    pages. If not, the original size is kept. This"
    echo "    option will run multiple passes of creating"
    echo "    PDFs. Only relevant for --format \"pdf\""
    echo ""
    echo "  --preserve-image-quality"
    echo "    Optional param. Keep the original image quality."
    echo ""
    echo "  --page-title \"PAGE TITLE\""
    echo "    Mandatory param. Title of page."
    echo ""
    echo "  --divide-by-year"
    echo "    Optional param. Collects articles into separate"
    echo "    files by year."
    echo ""
    echo "  --format \"[pdf|epub|markdown]\""
    echo "    Mandatory param. Which format to output to."
    echo ""
    echo "  --mark2epub-dir \"DIRECTORY\""
    echo "    Mandatory param if --format \"epub\" is given;"
    echo "    if not, this param will do nothing."
    echo "    The directory where mark2epub can be found,"
    echo "    which will create the epub file. This utility"
    echo "    can be downloaded from"
    echo "    https://github.com/AlexPof/mark2epub"
    echo ""
    echo "  --output-dir \"DIRECTORY\""
    echo "    Mandatory param. Directory to save output into."
}

print_error_and_quit() {
    echo ""
    echo "${1}"
    echo ""
    print_help
    exit 1
}


argv=("$@")
ignore_arg=0
for (( i=0; i<$#; i++ )); do
    arg="${argv[i]}"
    if [ $ignore_arg -gt 0 ]; then
        : $((ignore_arg--))
        continue
    fi
    case "$arg" in
    -h)
        ;&  # Fall through
    --help)
        print_help
        exit 0
        ;;
    --url)
        dn_address="${argv[i+1]}"
        ignore_arg=1
        ;;
    --cookie)
        cookie="${argv[i+1]}"
        if [[ "$cookie" != Cookie:* ]]; then
            echo "The cookie should start with 'Cookie: '"
            exit 1
        fi
        ignore_arg=1
        ;;
    --mark2epub-dir)
        mark2epub_dir="${argv[i+1]}"
        if [ ! -d "$mark2epub_dir" ]; then
            echo "Directory given for mark2epub does not exist: '$mark2epub_dir'"
            exit 1
        fi
        ignore_arg=1
        ;;
    --invalidate-cache)
        download="y"
        ;;
    --use-smaller-images-if-better-for-pdf)
        use_smaller_images_if_better="y"
        ;;
    --preserve-image-quality)
        preserve_img_quality="y"
        ;;
    --page-title)
        page_title="${argv[i+1]}"
        ignore_arg=1
        ;;
    --divide-by-year)
        divide_by_year="y"
        ;;
    --format)
        f="${argv[i+1]}"
        if [ "$f" == "pdf" ] || [ "$f" == "epub" ] || [ "$f" == "markdown" ]; then
            format="$f"
        else
            print_error_and_quit "Unknown value given to format parameter: '$f'"
        fi
        ignore_arg=1
        ;;
    --output-dir)
        output_dir="${argv[i+1]}"
        ignore_arg=1
        ;;
    *)
        print_error_and_quit "Unknown parameter: '$arg'"
        ;;
    esac
done

if [ -z "${dn_address}" ]; then
    print_error_and_quit "Missing required parameter 'url'"
elif [ -z "${page_title}" ]; then
    print_error_and_quit "Missing required parameter 'page-title'"
elif [ -z "${output_dir}" ]; then
    print_error_and_quit "Missing required parameter 'output-dir'"
elif [ -z "${cookie}" ]; then
    print_error_and_quit "Missing required parameter 'cookie'"
elif [ -z "${mark2epub_dir}" ] && [ "${format}" == "epub" ]; then
    print_error_and_quit "Missing required parameter 'mark2epub-dir'"
fi


download_article_list() {
  local offset=0
  local fetch_articles=""
  local result=0

  [ "$download" = "y" ] || [ ! -f "article_list" ] ; fetch_articles=$?
  while [ "$fetch_articles" -eq 0 ]; do
    echo "Downloading $offset articles"
    curl -s --header "${cookie}" "${dn_address}?offset=${offset}" | awk 'BEGIN{in_list = 0; url = ""; found_articles = 0;}{if ($0 ~ "<div class=\"timeline-page__listing\">") { url = ""; in_list = 1; } if ($0 ~ "<div class=\"pagination") in_list = 0; if ($0 ~ "<a href" && in_list) { sub(/ *<a href="/, "", $0); sub(/" .*/, "", $0); sub(/\/$/, "", $0); url = "https://www.dn.se" $0; } if ($0 ~ "<time " && in_list) { sub(/.*="/, "", $0); sub(/T.*/, "", $0); print $0 " " url >> "article_list"; found_articles = 1;}} END{if (!found_articles) exit 1;}'
    result=$?
    if [ $result -ne 0 ]; then
      break
    fi
    offset=$((offset+24))
  done
}

create_latex_for_article() {
  local dirname="${1}"
  local date="${dirname%%_*}" # Remove everything after '_'
  local pdf="article"
  local pages_big=0
  local pages_small=0
  local big=95
  local small=85

  sed 's|#TITLE#|'"${page_title}"'|g; s|#YEAR#|'"$date"'|g; s|#FILE#|'"$dirname"'|g; s|\\tableofcontents||g' ../../latex_defs.tex > article.tex

  xelatex article.tex 1> /dev/null
  if [ "$use_smaller_images_if_better" = "y" ]; then
    pages_big=$(pdfinfo article.pdf | awk '/^Pages:/ {print $2}')
    mv article.pdf big.pdf

    sed -i -E "s|includegraphics\[width=0.[0-9]+|includegraphics\[width=0.$small|g" "$dirname".tex
    xelatex article.tex 1> /dev/null
    pages_small=$(pdfinfo article.pdf | awk '/^Pages:/ {print $2}')
    mv article.pdf small.pdf

    if (( pages_big > pages_small )); then
      sed -i -E "s|includegraphics\[width=0.[0-9]+|includegraphics\[width=0.$small|g" "$dirname".tex
      pdf="small"
    else
      sed -i -E "s|includegraphics\[width=0.[0-9]+|includegraphics\[width=0.$big|g" "$dirname".tex
      pdf="big"
    fi
  fi
  mv "$pdf.pdf" "$dirname.pdf"
  rm -f small.pdf big.pdf article.{aux,log,out,toc}
 }

create_latex() {
  local dirname="${1}"
  local prevdir=""

  prevdir=$(pwd)
  cd "${dirname}" || exit 1

  # cmark-gfm doesn't do a good job with Latex images; do a hacky manual override
  sed -i -E "s/\!\[(.*)\]/@£\1¤/g" "${dirname}".md

  cmark-gfm -e table --table-prefer-style-attributes --to latex "${dirname}".md > "${dirname}.tex"

  # Reset image hack
  sed -i -E "s/@£(.*)¤/![\1]/g" "${dirname}".md

  # Recreate proper images and tables
  sed -i -E "s/@£(.*)¤\(([^ ]*) ?(.*)\)/\\\\begin\{figure\}\[ht\!\]\n\\\\centering\n\\\\includegraphics\[width=0.95\\\\textwidth\]\{\2\}\n\\\\caption\{\3 \1\}\n\\\\end\{figure\}/g" "${dirname}.tex"
  sed -i -E "s/\\\\begin\{tabular\}\{l\}/\\\\centering\\\\begin\{tabular\}\{\|p\{0.8\\\\linewidth\}\|\}\\\\hline\\\\\\\\/g" "${dirname}.tex"
  sed -i -E "s/\\\\end\{tabular\}/\\\\hline\n\\\\end\{tabular\}/g" "${dirname}.tex"
  awk 'BEGIN{in_head = 0;}{if ($0 ~ "\\\\section") { in_head = 1; print $0; } else if ($0 ~ "\\\\rule") { in_head = 0; print $0; } else if (in_head && $0 ~ "Av: ") print "\\begin{center}\\small{" $0 "\\\\"; else if (in_head && $0 ~ "Publicerad: ") print $0 "}\\end{center}"; else print $0;}' "${dirname}.tex" > tmp.tex && mv tmp.tex "${dirname}.tex"

  if [ "$use_smaller_images_if_better" = "y" ] || [ "$divide_by_year" = "n" ]; then
    create_latex_for_article "${dirname}"
  fi
  cd "${prevdir}" || exit 1
}

create_title_page_picture() {
  local date="${1}"
  local target="${2}"
  local dn_dl_root="${3}"
  local prevdir=""
  local tmpdir=""

  prevdir=$(pwd)
  tmpdir=$(mktemp --directory)
  cp "$dn_dl_root"/latex_defs.tex "$tmpdir"
  cd "$tmpdir" || exit 1

  sed -E "\
    s/#TITLE#/${page_title}/g ; \
    s/#YEAR#/$date/g ; \
    s/#FILE#/$date/g ; \
    s/\\newpage//g ; \
    s/\\tableofcontents//g ; \
    s/\\input\{.*.tex\}//g \
    " latex_defs.tex > cover.tex

  xelatex cover.tex 1> /dev/null
  pdftocairo -png cover.pdf
  cp cover-1.png "$prevdir"/"$target"/cover-"$date".png

  rm -rf "$tmpdir"
  cd "$prevdir" || exit 1
}

make_epub() {
  local workdir="${1}"
  local date="${2}"
  local chapters="${3}"
  local epub_fn="${4}"
  local prevdir=""

  prevdir=$(pwd)

  cp "$dn_dl_root"/epub_desc.json "$workdir"/description.json
  if [ -s "$dn_dl_root"/epub_style.css ]; then
    mkdir -p "$workdir"/css
    cp "$dn_dl_root"/epub_style.css "$workdir"/css
  else
    sed -i -E "s|\"default_css\":.*|\"default_css\":\[\],|" "$workdir"/description.json
  fi
  create_title_page_picture "$date" "$workdir/images" "$dn_dl_root"

  sed -i -E "\
    s|\"dc:title\":\".*\",|\"dc:title\":\"${page_title} - $date\",| ; \
    s|\"dc:date\":\".*\",|\"dc:date\":\"$(date -I)\",| ; \
    s|\"dc:identifier\":\".*\",|\"dc:identifier\":\"$(uuidgen)\",| ; \
    s|\"cover_image\":\".*\",|\"cover_image\":\"cover-$date.png\",| ; \
    s|\"chapters\":\[|\"chapters\":\[\n$chapters| \
    " "$workdir"/description.json

  cd "$mark2epub_dir" || exit 1

  python mark2epub.py "$prevdir/$workdir" "$prevdir/$workdir/$epub_fn" 1> /dev/null
  cd "$prevdir" || return
}

create_epub() {
  local dirname="${1}"
  local date="${2}"
  local dir="."
  local epub_filename="$dirname.epub"
  local chapters=""
  local prevdir=""

  prevdir=$(pwd)
  cd "$dirname" || exit 1
  for f in "$dir"/*.md; do
    chapters="${chapters}    {\"markdown\":\"$f\",\"css\":\"\"}"
  done

  make_epub "$dir" "$date" "$chapters" "$epub_filename"

  cd "$prevdir" || exit 1
}

download_article_and_imgs() {
  local dirname="${1}"
  local url="${2}"
  local fetch_article=0
  local fetch_img=0
  local origimg=""
  local imgname=""
  local prevdir=""

  prevdir=$(pwd)
  mkdir -p "${dirname}"
  cd "${dirname}" || exit 1

  [ "$download" = "y" ] || [ ! -f "${dirname}.html" ] ; fetch_article=$?
  if [ "$fetch_article" -eq 0 ]; then
    curl -L -s --header "${cookie}" "${url}" > "${dirname}.html"
  fi
  ../../parser.awk "${dirname}.html" > "${dirname}.md"

  if [ ! -f imgs ]; then
    echo "No images found!"
    echo
  else
    mkdir -p images
    while read -r img; do
      origimg="${img//[\/:]/_}"
      imgname="images/${img//[\/:]/_}"
      sed -i -E "s|${origimg}|${imgname}|g" "${dirname}.md"

      [ "$download" = "y" ] || [ ! -f "$imgname" ] ; fetch_img=$?
      if [ "$fetch_img" -eq 0 ]; then
        curl -s -L --retry 5 "${img}" -o "${imgname}"
        if [ "$preserve_img_quality" = "n" ]; then
          convert "${imgname}" -quality 50% -resize 50% "${imgname}"
        fi
      fi
    done < imgs
  fi
  cd "$prevdir" || exit 1
}

download_and_process_articles() {
  local prevdir=""
  local name=""
  local dirname=""

  prevdir=$(pwd)
  mkdir -p "${output_dir}"
  cd "${output_dir}" || exit 1

  while read -r date url; do
    name="${url##*/}"
    dirname="${date}_${name}"
    echo "${date} - ${name}"

    download_article_and_imgs "${dirname}" "${url}"
    if [ "${format}" == "pdf" ]; then
      create_latex "${dirname}"
    elif [ "${format}" == "epub" ]; then
      create_epub "${dirname}" "${date}"
    fi
  done < ../article_list

  cd "$prevdir" || exit 1
}

create_output_groups_by_year() {
  local chapters=""

  cd "${output_dir}" || exit 1
  for year in $(seq $first_year "$(date +%Y)"); do
    if ls "$year"-* 1> /dev/null 2>&1; then

      if [ "${format}" == "pdf" ]; then
        chapters=$(find . -type f -path "./$year-*/*.tex" ! -name "article.tex" | sort)
        echo "\graphicspath{%" > "$year.tex"
        echo "$chapters" | sed -E 's|^./(.*)/.*|{./\1}%|' >> "$year".tex
        echo "}" >> "$year.tex"
        echo "$chapters" | sed 's/^/\\include{/; s/$/}/' >> "$year".tex
        sed 's/#TITLE#/'"${page_title}"'/g; s/#YEAR#/'"$year"'/g; s/#FILE#/'"$year"'/g' ../latex_defs.tex > articles_"$year".tex

        for i in $(seq 1 2); do
          xelatex articles_"$year".tex
        done
        rm -f articles_"$year".{aux,log,out,toc}

      elif [ "${format}" == "epub" ]; then
        local dir="epub-$year"
        local epub_filename="$year.epub"

        mkdir -p "$dir"/images
        cp "$year"-*/*.md "$dir"
        chapters=$(find . -type f -path "./$dir/*.md" -printf "%f\n" | sort | sed 's/^/    {\"markdown\":\"/ ; s/$/\",\"css\":\"\"},/' | tr -d '\n')
        chapters=${chapters:0:-1}
        find "$year"-* -maxdepth 2 -type f -regex ".*\.\(jpeg\|jpg\|gif\|png\)" -exec cp {} "$dir"/images \;

        make_epub "$dir" "$year" "$chapters" "$epub_filename"
      fi
    fi
  done
}

echo
dn_dl_root=$(pwd)

download_article_list
download_and_process_articles

if [ "$divide_by_year" = "y" ]; then
  echo
  cd "${dn_dl_root}" || exit 1
  create_output_groups_by_year
fi

cd "${dn_dl_root}" || return
