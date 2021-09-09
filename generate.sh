#!/bin/sh

mkdir -p web

. ./settings.sh

DateStamp() {
    sed -i '$ d' $1
    echo -n "<p>Page Last Edited: " >> $1
    echo -n "$2" | sed -s 's/Date: //' >> $1
    echo "</p>" >> $1
    echo -n "</html>" >> $1

}

# CAT comes from settings.sh
GetCategory() {
    USECATEGORY=$1
    for i in $(seq 1 $CATCOUNT)
    do
	A=CAT$i
	B=CATNAME$i
	A=$(eval echo \$$A)
	B=$(eval echo \$$B)
        test "$1" = "$A" && USECATEGORY="$B"
        test "$1" = "$B" && USECATEGORY="$1"
    done
}

# create index page 
rm index.groff
custom_index=`cat index_custom.groff`
echo ".B \"""$SITEDESCRIPTION""\"" >> index.groff
echo "" >> index.groff
echo ".MTO "$MAILTO >> index.groff
echo "" >> index.groff
for i in $(seq 1 $CATCOUNT) 
do
    A=CAT$i
    B=CATNAME$i
    A=$(eval echo \$$A)
    B=$(eval echo \$$B)
    PAGEFILENAME=$(echo "$A" | tr '[A-Z]' '[a-z]')
    echo ".URL "$PAGEFILENAME".html \""$B"\"" >> index.groff
    echo "" >> index.groff
done
cat index_custom.groff >> index.groff
# generate index page
groff -ms -mwww -T html index.groff > web/index.html

# generate sub pages
for i in $(seq 1 $CATCOUNT)
do
    A=CAT$i
    B=CATNAME$i
    A=$(eval echo \$$A)
    B=$(eval echo \$$B)
    PAGEFILENAME=$(echo "$A" | tr '[A-Z]' '[a-z]')
    rm -f "$PAGEFILENAME".groff
    test -f "$PAGEFILENAME"_custom.groff && cat "$PAGEFILENAME"_custom.groff >> $PAGEFILENAME.groff
    echo "" >> $PAGEFILENAME.groff
    echo ".B \"Recent Posts\"" >> $PAGEFILENAME.groff    
    for f in $(ls -1r posts/*/*/*)
    do
        LINK=$(echo $f | sed "s/.groff/.html/g")
        CATEGORY=$(grep -r -m1 ".CAT" "$f" | sed "s/.CAT //g")
        TITLE=$(grep -r -m1 ".TL" "$f" | sed "s/.TL/ /g" | sed "s/_/ /g")
        test "$CATEGORY" = "$A" && echo "" >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$B" && echo "" >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$A" && echo -n ".URL " >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$A" && echo -n $LINK" " >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$B" && echo -n ".URL " >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$B" && echo -n $LINK" " >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$A" && echo "\""$TITLE"\"" >> $PAGEFILENAME.groff
        test "$CATEGORY" = "$B" && echo "\""$TITLE"\"" >> $PAGEFILENAME.groff
    done
    rm -f web/$PAGEFILENAME.html
    groff -ms -mwww -T html $PAGEFILENAME.groff > web/$PAGEFILENAME.html
done

# turn posts into html
for f in posts/*/*/*
  do
    mkdir -p "web/"$(dirname $f)"/"
    GENERATED="web/"$(dirname $f)"/"$(basename $f .groff).html

    groff -ms -mwww -T html $f > $GENERATED
    #groff -ms -mwww -T html $f > "web/"$(dirname $f)"/"$(basename $f .groff).html

    DateStamp $GENERATED "$(git log -1 --date=format:'%Y-%m-%d %H:%M:%S' -- $f | tail -n3 | head -n1)"
done

# datesstamp htmls
for f in web/*.html
    do
	useDate="$(git log --date=format:'%Y-%m-%d %H:%M:%S' -1 -- $(basename $f .html)_custom.groff | tail -n3 | head -n1)"
	test "$useDate" = "" && useDate="$(date +'%Y-%m-%d %H:%M:%S')"
        DateStamp $f "$useDate"
done

rm -f now.groff
grep -r ".TL" $(ls -1r posts/*/*/*) | sed "s/.groff/.html/g" | sed "s/posts/\n.URL posts/g" | sed "s/:.TL / /g" >> now.groff
groff -ms -mwww -T html now.groff > web/now.html
DateStamp web/now.html "$(date +'%Y-%m-%d %H:%M:%S')"

echo "<rss version=\"2.0\">
    <channel>
        <title>$SITENAME</title>
        <link>$SITEADDRESS</link>
        <description>$SITEDESCRIPTION</description>
        <generator>BoomerCMS</generator>" > web/rss.xml
for f in posts/*/*/*
    do
        USECATEGORY=
        GENERATED="/"$(dirname $f)"/"$(basename $f .groff).html
        DATE=$(git log --date=rfc --diff-filter=A -- "$f" | grep "Date:"| sed "s/Date:   //g")
        echo "        <item>" >> web/rss.xml
        SPACES="            "
        TITLE=$(grep -r -m1 ".TL" "$f" | sed "s/.TL //g" | sed "s/_/ /g")
        CATEGORY=$(grep -r -m1 ".CAT" "$f" | sed "s/.CAT //g")
        AUTHOR=$(grep -r -m1 ".AU" "$f" | sed "s/.AU //g")
        GetCategory $CATEGORY
        echo "$SPACES<title>$TITLE</title>" >> web/rss.xml
        echo "$SPACES<link>$SITEADDRESS$GENERATED</link>" >> web/rss.xml
        echo "$SPACES<description>$TITLE</description>" >> web/rss.xml
        echo "$SPACES<author>$AUTHOR</author>" >> web/rss.xml
        echo "$SPACES<category>$USECATEGORY</category>" >> web/rss.xml
        echo "$SPACES<pubDate isPermaLink=\"true\">$DATE</pubDate>" >> web/rss.xml
        echo "$SPACES<guid>$SITEADDRESS$GENERATED</guid>" >> web/rss.xml
        echo "        </item>" >> web/rss.xml
    done
echo "    </channel>" >> web/rss.xml
echo "</rss>" >> web/rss.xml

