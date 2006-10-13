
require 'camping'
require 'mechanize'

Camping.goes :Pdfetch

module Pdfetch::Controllers

  class MainCss < R '/main.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = %{

/* main.css */
body { margin: 0; padding: 10; font-size: medium; font-family: arial, sans; }
a { text-decoration: none;}
h1 { font-size: 110%; }
p { font-size: 90%; }

}
    end
  end

  class Index < R '/'
    def get
      redirect "http://code.google.com/p/pdfetch/"
    end
  end
  
  class Static < R '/(\d+)\.pdf$'         
    def get(id)
      @pmid = id
      @headers['Content-Type'] = "application/pdf"
      @headers['X-Sendfile'] = "#{Dir.getwd}/#{id}.pdf"
    end
  end 
  

  class Fetch < R '/fetch/(\d+)$'
    
    def get(id)
      @pmid = id
      @uri = nil
      begin
        unless File.exist?("#{id}.pdf")
          m = WWW::Mechanize.new
          p = m.get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=#{id}&retmode=ref&cmd=prlinks")
          @uri = p.uri
  
          if link = p.links.with.text(/pdf/i).and.href(/pdfstart/i) and not link.empty?
            puts "fetching #{id} (wiley)..."
            p = m.click link
            p = m.click p.frames.with.name(/main/i).and.src(/mode=pdf/i)
          
          elsif link = p.links.with.href(/fulltext.pdf$/i) and not link.empty?
            puts "fetching #{id} (springerlink)..."
            p = m.click link

          elsif link = p.links.with.href(/task=readnow/i) and not link.empty?
            puts "fetching #{id} (humana press)..."
            p = m.click link
           
          elsif link = p.links.with.text(/pdf|full[\s-]?text|reprint/i).and.href(/.pdf$/i) and not link.empty?
            puts "fetching #{id} (generic)..."
            p = m.click link

          elsif link = p.links.with.text(/sciencedirect/i).and.href(/sciencedirect/i) and not link.empty?
            puts "fetching #{id} (sciencedirect)..."
            p = m.click link
            p = m.click p.links.with.text(/pdf/i).and.href(/.pdf$/i)
          
          elsif link = p.links.with.text(/pdf/i).and.href(/reprint/i) and not link.empty?
            puts "fetching #{id} (jbc)..."
            p = m.click link
            p = m.click p.frames.with.name(/reprint/i)
            p = m.click p.links.with.href(/.pdf$/i)
         
          elsif link = p.links.with.text(/full text/i).and.href(/full/i) and not link.empty?
            puts "fetching #{id} (npg)..."
            p = m.click link
            p = m.click p.links.with.href(/.pdf$/i)
          
          elsif frame = p.frames.with.name(/reprint/i) and not frame.empty?
            puts "fetching #{id} (???)..."
            p = m.click frame
            p = m.click p.links.with.href(/.pdf$/i)
          end
          
          if p.kind_of? WWW::Mechanize::File
            p.save_as("#{id}.pdf")
          else
            raise
          end
        
        end
        puts "fetching of #{id} succeeded (or reprint already in library)"
        puts
        render :success
      rescue
        puts "fetching of #{id} failed"
        puts
        render :failure
      end
    end
  end    

  class Check < R '/check/(\d+)$'
    def get(id)
      return File.exist?("#{id}.pdf")
    end
  end

end

  
module Pdfetch::Views

  def layout
    html do
      head do
#        link :rel => 'stylesheet', :type => 'text/css', :href => '/main.css', :media => 'screen'
        script "function gotouri(){location.href=\"#{@uri}\";} function gotopdf(){location.href=\"/#{@pmid}.pdf\";} function goback(){window.history.back()} function waitngoback(){window.setTimeout(goback(),3000);}", :type => 'text/javascript'
      end
      self << yield
    end
  end

  def success
    body :onload => 'gotopdf()' do nil end
  end

  def failure
    if @uri
      body :onload => 'gotouri()' do nil end
    else
      body :onload => 'goback()' do nil end
    end
  end

end
