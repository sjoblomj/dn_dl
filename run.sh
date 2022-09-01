#!/bin/bash

dn_adress="https://www.dn.se/av/andrev-walden/"
page_title="Andrev Walden"
download=0 #Convenience flag - turn off to use what has already been downloaded in previous runs

function download_article_list() {
  offset=0
  while [ $download -eq 1 ]; do
    echo "Downloading $offset articles"
    curl -s --header "$(cat dn_header)" "${dn_adress}?offset=${offset}" | awk 'BEGIN{in_list = 0; url = ""; found_articles = 0;}{if ($0 ~ "<div class=\"timeline-page__listing\">") { url = ""; in_list = 1; } if ($0 ~ "<div class=\"pagination") in_list = 0; if ($0 ~ "<a href" && in_list) { sub(/ *<a href="/, "", $0); sub(/" .*/, "", $0); sub(/\/$/, "", $0); url = "https://www.dn.se" $0; } if ($0 ~ "<time " && in_list) { sub(/.*="/, "", $0); sub(/T.*/, "", $0); print $0 " " url >> "article_list"; found_articles = 1;}} END{if (!found_articles) exit 1;}'
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
      break
    fi
    offset=$((offset+24))
  done
}

function create_latex() {
  date="${1}"
  name="${2}"

  # cmark-gfm doesn't do a good job with Latex images; do a hacky manual override
  sed -i -E "s/\!\[(.*)\]/@£\1¤/g" article.md

  cmark-gfm -e table --table-prefer-style-attributes --to latex article.md > "${name}.tex"

  # Recreate proper images and tables
  sed -i -E "s/@£(.*)¤\(([^ ]*) ?(.*)\)/\\\\begin\{figure\}\[ht\!\]\n\\\\centering\n\\\\includegraphics\[width=0.95\\\\textwidth\]\{${date}_${name}\/\2\}\n\\\\caption\{\3 \1\}\n\\\\end\{figure\}/g" "${name}.tex"
  sed -i -E "s/\\\\begin\{tabular\}\{l\}/\\\\centering\\\\begin\{tabular\}\{\|p\{0.8\\\\linewidth\}\|\}\\\\hline\\\\\\\\/g" "${name}.tex"
  sed -i -E "s/\\\\end\{tabular\}/\\\\hline\n\\\\end\{tabular\}/g" "${name}.tex"
  cat "${name}.tex" | awk 'BEGIN{in_head = 0;}{if ($0 ~ "\\\\section") { in_head = 1; print $0; } else if ($0 ~ "\\\\rule") { in_head = 0; print $0; } else if (in_head && $0 ~ "Av: ") print "\\begin{center}\\small{" $0 "\\\\"; else if (in_head && $0 ~ "Publicerad: ") print $0 "}\\end{center}"; else print $0;}' > tmp.tex && mv tmp.tex "${name}.tex"
}

function article_to_pdf() {
  date="${1}"
  url="${2}"
  name="${url##*/}"
  mkdir -p "${date}_${name}"
  cd "${date}_${name}"
  echo "${date} - ${name}"

  if [ $download -eq 1 ]; then
    curl -L -s --header "$(cat ../../dn_header)" "${url}" > article.html
  fi
  ../../parser.awk article.html > article.md

  if [ ! -f imgs ]; then
    echo "No images found!"
    echo
  else
    while read img; do
      imgname=$(echo "${img}" | sed 's|[/:]|_|g')
      if [ $download -eq 1 ]; then
        curl -s -L --retry 5 "${img}" -o "${imgname}"
        convert "${imgname}" -quality 50% -resize 50% "${imgname}"
      fi
    done < imgs
  fi

  create_latex "${date}" "${name}"
  cd - > /dev/null
}

function articles_to_pdf() {
  mkdir -p articles
  cd articles

  while read date url; do
    article_to_pdf "$date" "$url"
  done < ../article_list

  cd -
}

function create_pdfs_by_year() {
  cd articles
  for y in $(seq 1864 $(date +%Y)); do
    if ls $y-* 1> /dev/null 2>&1; then
      ls -1 $y-*/*.tex | sed 's/^/\\include{/' | sed 's/$/}/' > $y.tex
      cat ../latex_defs.tex | sed 's/#TITLE#/'"${page_title}"'/g' | sed 's/#YEAR#/'"$y"'/g' > articles_$y.tex

      for i in $(seq 1 2); do
        xelatex articles_$y.tex
      done
    fi
  done
}

dir=$(pwd)

download_article_list
articles_to_pdf

echo
cd "${dir}"
create_pdfs_by_year

cd "${dir}"
