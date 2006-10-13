
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
      begin
        unless File.exist?("#{id}.pdf")
          m = WWW::Mechanize.new
          p = m.get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=#{id}&retmode=ref&cmd=prlinks")
          
          # generic
          if link = p.links.with.text(/pdf/i).and.href(/.pdf$/i) and not link.empty?
            p = m.click link
            p.save_as("#{id}.pdf")
          # wiley interscience
          elsif link = p.links.with.text(/pdf/i).and.href(/pdfstart/i) and not link.empty?
            p = m.click link
            p = m.click p.frames.with.name(/main/i).and.src(/mode=pdf/i)
            p.save_as("#{id}.pdf")
          # npg
          elsif link = p.links.with.text(/full/i).and.href(/full/i) and not link.empty?
            p = m.click link
            p = m.click p.links.with.href(/.pdf$/i)
            p.save_as("#{id}.pdf")
          # ???
          elsif frame = p.frames.with.name(/reprint/i) and not frame.empty?
            p = m.click frame
            p = m.click p.links.with.href(/.pdf$/i)
            p.save_as("#{id}.pdf")
          # j neurosci, j biol chem, etc
          else
            p = m.click p.links.with.text(/pdf/i).and.href(/reprint/i)
            p = m.click p.frames.with.name(/reprint/i)
            p = m.click p.links.with.href(/.pdf$/i)
            p.save_as("#{id}.pdf")
          end
        end
        render :success
      rescue
        render :error
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
        script "function gotopdf(){location.href=\"/#{@pmid}.pdf\";} function goback(){window.history.back()} function waitngoback(){window.setTimeout(goback(),3000);}", :type => 'text/javascript'
      end
      self << yield
    end
  end

  def success
    body :onload => 'gotopdf()' do nil end
  end

  def error
    body :onload => 'goback()' do nil end
  end

end
