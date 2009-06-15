#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script gets random wikipedia page and starts espeak to read it
#
# Extra features:
# 
# (some artistic solutions to get intresting data in human form)
#
# 1. random voice from category names
# trying to ...
# 2. cut abuse and uninteresting data like too large tables and catalogues
# 3. generate associative pages as output
# 4. humanize expressions and metrics data
# 5. use intersting factors in category names ...
#
# unicode
$KCODE = 'u'
require 'jcode'

#requirements
require 'rubygems'
require 'nokogiri'
require 'mechanize'


PAGE = nil #ARGV.size > 0 ? ARGV[0] : nil
# temporary file data
DIR = "/tmp"
FILENAME = 'wikipedia.txt'

MAX_COUNTER = ARGV.size > 0 ? ARGV[0].to_i : 10

TABLAZAT_LIMIT = 800
LISTA_LIMIT = 800

SANITIZE_THIS = ['Arra kérünk, szánj egy percet.*',
  '- Wiki.*','A Wikipédiából.*',
  '\[.*?\]']

ROMAISZAMOK = {
  'I' => 'első',
  'II' => 'második',
  'III' => 'harmadik',
  'IV' => 'negyedik',
  'V' => 'ötödik',
  'VI' => 'hatodik',
  'VII' => 'hetedik',
  'VIII' => 'nyolcadik',
  'IX' => 'kilencedik',
  'X' => 'tizedik',
  'XI' => 'tizenegyedik',
  'XII' => 'tizenkettedik',
  'XIII' => 'tizenharmadik',
  'XIV' => 'tizennegyedik',
  'XV' => 'tizenötödik',
  'XVI' => 'tizenhatodik',
  'XVII' => 'tizenhetedik',
  'XVIII' => 'tizennyolcadik',
  'XIX' => 'tizenkilencedik',
  'XX' => 'huszadik',
  'XXI' => 'huszonegyedik'
}

P = (1..6).map{|x| x * 20 }
V = ['hu+f1','hu+f2','hu+f3','hu+f4','hu+m1','hu+m2','hu+m3','hu+m4','hu+m5','hu+m6']
S = (1..4).map{|x| 40 + x * 50 }

def speak_command( p, v, s )
  "espeak -p #{p} -v #{v} -s #{s} -a 99 -w /tmp/wiki_wav/TMPFILENAME.wav -f"
end

def generate_voice uid
  uid = uid.sum
  speak_command( P[uid % P.length], V[uid % V.length], S[uid % S.length])
end

CATEGORY_OFFSET = 20
# regex, and interesting factor in percents
CATEGORY_FACTORS = {
# --- nem érdekes :(
  # Föci
  /település/iu => 25,
  /község/iu => 40,
  /megye/iu => 40,
  /város/iu => 60,
  /tartomány/iu => 60,
  /körzet/iu => 60,
  # wiki alap
  /list[aá]/iu => 40,
  /egyértelműsítő/iu => 40,
  # művek
  /középfölde/iu => 25,
  /csillagok háborúja/iu => 25,
  /formula–1/iu => 30,
  # sport
  /sport/iu => 40,
  /sportélet/iu => 60,
  /labdarúg/iu => 30,
  /kézilabda/iu => 30,
  # zene
  /(nagy|kis)lemez/iu => 60,
  /albumok/iu => 60,
  /együttes/iu => 65,
  /zene/iu => 60,
  # film
  /filmes listák/iu => 25,
  /film/iu => 50,
  # töri - idő
  /század/iu => 60,
  /évszázad/iu => 35,
  /évtized/iu => 35,
  /Az év napjai/iu => 75,
  /történel/iu => 50,
  /ókor/iu => 75,
  # vallás
  /püspök/iu => 70,
  /érsek/iu => 70,
  /egyház/iu => 70,
# --- érdekes ! :)
  /csillag/iu => 140,
  /fizik/iu => 130,
  /matematik/iu => 130,
  /pszich/iu => 130,
  /társadal/iu => 120,
  /tudomány/iu => 140,
  /informatika/iu => 120,
  /szoftver/iu => 130,
}
#

def interesting? in_category
  fact = 1.to_f
  CATEGORY_FACTORS.keys.each do |regex|
    fact = fact * (CATEGORY_FACTORS[regex].to_f / 100) if in_category =~ regex
  end

  r = rand
  fact = fact - ( CATEGORY_OFFSET.to_f / 100 )
  if r < fact
    puts "interesting: #{in_category} (#{r}<#{fact})"
    return true
  else
    puts "not interesting: #{in_category} (#{r}<#{fact})"
    return false
  end
end

# kill everything from text, we wont hear
def sanitize text
  SANITIZE_THIS.each { |s|  text = text.gsub(/#{s}/,'') }

  #római számok kiegészítés
  text = text.gsub(/\W*(#{ROMAISZAMOK.keys.join('|')})\.\W*(\w+)/) do 
    ROMAISZAMOK[$1] ? ( ROMAISZAMOK[$1] + ' ' + $2 ) : $&
  end
  
  #századok
  text = text.gsub(/(\W*)(#{(1..21).to_a.join('|')})\.\W+század/) do
    $1 + ROMAISZAMOK.values[($2.to_i - 1)]+' század'
  end

  #törtek ( itt mind , mind . után jön egy számsorozat
  text = text.gsub(/(\d+)[,.](\d+)/) { $1 + ' egész,' + $2 + ' ' }

  #külön írt számok, ha az első nem csatlakozik karakterhez, mint bolygónevek pl M4079 448 km/sec
  # és a második 3 karakter, hogy táblázatban lévő évszámokat pl ne vonjon össze
  text = text.gsub(/(\W\d+)\s(\d{3})/) { $1 + $2 }

  #idegesített az isbn
  text = text.gsub(/(ISBN)\s*([0-9\-]+)$/i) { 'iesbéen ' + $2.split('').join(' ') }

  # ie isz kr e kr u
  text = text.gsub(/(i\.{0,1}\s{0,1}sz\.{0,1})\s{0,1}(\d)/i){ ' időszámításunk szerint ' + $2 }
  text = text.gsub(/([kK]r\.{0,1}\s{0,1}sz\.{0,1})\s{0,1}(\d)/){ ' Krisztus szerint ' + $2 }
  text = text.gsub(/([kK]r\.{0,1}\s{0,1}u\.{0,1})\s{0,1}(\d)/){ ' Krisztus után ' + $2 }
  text = text.gsub(/(i\.{0,1}\s{0,1}e\.{0,1})\s{0,1}(\d)/){ ' időszámításunk előtt ' + $2 }
  text = text.gsub(/([kK]r\.{0,1}\s{0,1}e\.{0,1})\s{0,1}(\d)/){ ' Krisztus előtt ' + $2 }

  # kis mértékegység hekk
  text = text.gsub(/\Wkm\/h\W/,' km per óra ')
  text = text.gsub(/\WkW\W/,' kilo watt ')
  text = text.gsub(/\Wkg\W/i,' kilo gramm ')
  text = text.gsub(/(\d+)\W+m\W/) { $1 + ' méter '}
  text = text.gsub(/°/,' fok')
  text = text.gsub(/[&]i/,' és ')
  # négyzet - sokszor előfordul földrajzban
  text = text.gsub(/km\W{0,1}²/i){ ' négyzet km ' }
  # négyzet - matekban változó után jön. :/, mértékegységeknél előtte, mértékegységeket ki kéne szedni tömbbe
  text = text.gsub(/²/){ ' négyzet ' }
  text = text.gsub(/\+\/\-/,' plussz minusz ')
  text = text.gsub(/×/,' szor ')

  # deokosvagyok rövidítésekbű
  text = text.gsub(/\sstb\.\s/i, ' satöbbi ')
  text = text.gsub(/\sun\.\s/i, ' úgy nevezett ')
  text
end

def to_say f, text
  text = sanitize( text )
  f.puts text + ' '
  #puts text
end

def parse_node f, node, depth=0
  return if depth > 30
  if node.is_a? Nokogiri::XML::Element
    if node.name =~ /^h.$/
      to_say( f, node.inner_text + "\n\n" )
    elsif node.name =~ /^p$/
      to_say( f,  node.inner_text + "\n")
    elsif node.name =~ /^a$/
      to_say( f, node.inner_text + "\n")
    elsif node.name =~ /^img$/
      to_say( f, 'KÉP: ' + (node/"@title").to_s + "\n")
    elsif node.name =~ /^table$/
      if node.inner_text =~ /Tartalomjegyzék/u
        to_say( f, node.inner_text.gsub(/[0123456789.]{1,3}/,'').split("\n").join(".\n") )
      elsif node.inner_text =~ /m\W{0,3}v{0,3}sz/u
        return
      else
        if node.inner_text.size > TABLAZAT_LIMIT
          to_say(f, "Túl nagy táblázat. \n")
        else
          to_say( f, 'TÁBLÁZAT: ' + node.inner_text.split("\n").join(".\n")  + "\n")
        end
      end
    elsif node.name =~ /^(ul|ol)$/
      if node.inner_text.size > TABLAZAT_LIMIT
        to_say( f, "Túl nagy felsorolás. \n")
      else
        to_say( f, "Felsorolás:\n" + node.inner_text.split("\n").join(".\n") + "\n")
      end
    end
    return
  end

  (node/"./*").each do |child|
    parse_node(f, child, depth+1)
  end
end

#load '/etc/my_ruby_scripts/settings.rb'
BLOG_NAME = 'csakacsuda'

def push_to_freeblog email,password,message
  #return if message['text'] =~ /@|http/
  agent, agent.user_agent_alias, agent.redirect_ok = WWW::Mechanize.new, 'Linux Mozilla', true
  f = agent.get('http://freeblog.hu').forms.select {|lf| lf.action == 'fblogin.php'}.first
  @@freeblogpwd ||= password
  f.username, f.password = email,password 
  f.checkboxes.first.uncheck
  m = agent.submit(f)
  #m = agent.get("http://admin.freeblog.hu/edit/#{@@freebloguser}/entries")
  m = agent.get("http://admin.freeblog.hu/edit/#{BLOG_NAME}/entries/create-entry")
  m.forms.first.fields.select { |f| f.name =~ /CONTENT/ }.first.value = message

  agent.submit(m.forms.first)

  puts 'freeblog -> OK'
rescue
  puts 'freeblog -> ERROR' 
end

WIKIPEDIA_MAIN = 'http://hu.wikipedia.org'

# find first image, and post link to blog
def hunt_for_wiki_image_in links, agent
  return
  links.each{|l| puts l.href}
  STDIN.gets
  if links = links.compact.select{|l| l.href =~ /(?!book)(.*)F.*jl.*(jpg|png|gif|JPG|PNG|GIF)/}
    unless links.empty?
      link = agent.get( "#{WIKIPEDIA_MAIN}#{links[ rand(links.size) ]}" ).links.select{|l| l.href =~ /.*\.(jpg|png|gif|JPG|PNG|GIF).*/}.first.href

      push_to_freeblog(@@settings[:freeblog].first,@@settings[:freeblog].last,link)
    else
      puts 'nincs kép'
    end
  end
end

def generate_filename title
  file_name = title.gsub(/[^a-zA-Z0-9]/){''}
  ret = generate_voice(@@category).gsub(/TMPFILENAME/) do
    file_name
	end

  #mp3title_file
  File.open("/tmp/wiki_wav/#{file_name}.wav.title",'w') do |f|
    f.puts title 
  end

  ret
end

#make a new mechanize user agent
agent, agent.user_agent_alias, agent.redirect_ok = WWW::Mechanize.new, 'Linux Mozilla', true

RANDOM_PAGE_LINK = WIKIPEDIA_MAIN + '/wiki/Speci%C3%A1lis:Lap_tal%C3%A1lomra'

i = 1
#infinite loop, and counter
links = []
last_link = ''
new_link = ''
while i > 0
  #download random page
  unless PAGE
    url = [RANDOM_PAGE_LINK] + links
    # find a really new link
    new_link = url[rand(url.size)] while new_link == last_link
    
    url = new_link.dup
    last_link = new_link.dup unless new_link == RANDOM_PAGE_LINK
    
    oldal = agent.get url
    links = oldal.links.select{|l| l.href =~ /^\/wiki\/(?!(Wikip|Kateg|Speci|Kezd.*lap|F.*jl|Vita)).*/}.map{|l| l.href =~ /^http/ ? l.href : "#{WIKIPEDIA_MAIN}#{l.href}" }
  else
    oldal = agent.get PAGE
  end

  if cat = (oldal/"#bodyContent/div#catlinks")
    @@category = cat.inner_text.gsub(/Kategóriák:|Kategória:/,'') 
    # this is the interesting check trick :)
    next unless interesting?( @@category )
  end

	#write to file and parse content
  File.open("#{DIR}/#{FILENAME}",'w') do |f|
    #Kategória
    to_say( f, @@category + "\n" ) if @@category 
    #title
    puts "Cikk##{i} - link : #{oldal.uri.to_s}"
    to_say( f, oldal.title )
    #parse_content
    wiki = false
    (oldal/"#bodyContent/*").each { |child| wiki = true; parse_node(f,child) }

    (oldal/"body/*").each { |child| parse_node(f,child) } unless wiki

    #footer
    f.puts "VÉGE."
  end
  #say
  system "#{generate_filename(oldal.title)} #{DIR}/#{FILENAME}"
  #increment counter and garbage collect
  i = i+1
  ObjectSpace.garbage_collect
  break if PAGE or MAX_COUNTER < i
end
