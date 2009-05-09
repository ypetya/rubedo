#!/usr/bin/env ruby
#
# Kiss Péter - ypetya@gmail.com
#
# This simple script gets random wikipedia page and starts espeak to read it

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

#SPEAK_COMMAND = ARGV.size > 1 ? "espeak -p 78 -v #{ARGV[1]} -s 150 -a 99 -f": 'aoss espeak -p 78 -v hu+f2 -s 150 -a 99 -f'
MAX_COUNTER = ARGV.size > 0 ? ARGV[0].to_i : 10

SPEAK_COMMAND = "espeak -p 78 -v hu+f2 -s 150 -a 99 -w /tmp/wiki_wav/TMPFILENAME.wav -f"


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
  text = text.gsub(/(ISBN)\s*([0-9\-]+)$/) { 'iesbéen ' + $2.split('').join(' ') }

  # ie isz kr e kr u

  text = text.gsub(/(i\.{0,1}\s{0,1}sz\.{0,1})\s{0,1}(\d)/){ ' időszámításunk szerint ' + $2 }
  text = text.gsub(/([kK]r\.{0,1}\s{0,1}sz\.{0,1})\s{0,1}(\d)/){ ' Krisztus szerint ' + $2 }
  text = text.gsub(/([kK]r\.{0,1}\s{0,1}u\.{0,1})\s{0,1}(\d)/){ ' Krisztus után ' + $2 }
  text = text.gsub(/(i\.{0,1}\s{0,1}e\.{0,1})\s{0,1}(\d)/){ ' időszámításunk előtt ' + $2 }
  text = text.gsub(/([kK]r\.{0,1}\s{0,1}e\.{0,1})\s{0,1}(\d)/){ ' Krisztus előtt ' + $2 }

  # kis mértékegység hekk
  text = text.gsub(/\Wkm\/h\W/,' km per óra ')
  text = text.gsub(/\WkW\W/,' kilo watt ')
  text = text.gsub(/\Wkg\W/,' kilo gramm ')
  text = text.gsub(/(\d+)\W+m\W/) { $1 + ' méter '}
  text = text.gsub(/°/,' fok')
  text = text.gsub(/[&]/,' és ')
  # négyzet - sokszor előfordul földrajzban
  text = text.gsub(/km\W{0,1}²/){ ' négyzet km ' }
  # négyzet - matekban változó után jön. :/, mértékegységeknél előtte, mértékegységeket ki kéne szedni tömbbe
  text = text.gsub(/²/){ ' négyzet ' }
  text = text.gsub(/\+\/\-/,'plussz minusz')

  # deokosvagyok rövidítésekű
  text = text.gsub(/\sstb\.\s/, ' satöbbi ')
  text = text.gsub(/\sun\.\s/, ' úgy nevezett ')
  text
end

def to_say f, text
  text = sanitize( text )
  f.puts text + ' '
  puts text
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
      if node.inner_text =~ /Tartalomjegyzék/
        to_say( f, node.inner_text.gsub(/[0123456789.]{1,3}/,'').split("\n").join(".\n") )
      elsif node.inner_text =~ /m·v·sz/
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

def generate_filename counter
  SPEAK_COMMAND.gsub(/TMPFILENAME/) do
		counter = counter.gsub(/[^a-zA-Z0-9]/){''}
	end
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
  #grab images :)
  #hunt_for_wiki_image_in oldal.links,agent
  
	#write to file and parse content
  File.open("#{DIR}/#{FILENAME}",'w') do |f|
    #Kategória
    if cat = (oldal/"#bodyContent/div#catlinks")
      to_say f, cat.inner_text.gsub(/Kategóriák:|Kategória:/,'') + "\n"
    end
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
  #puts generate_filename(oldal.title)
	#gets
  system "#{generate_filename(oldal.title)} #{DIR}/#{FILENAME}"
  #increment counter and garbage collect
  i = i+1
  ObjectSpace.garbage_collect
  break if PAGE or MAX_COUNTER < i
end
