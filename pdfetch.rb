require 'camping'
require 'mechanize'

Camping.goes :Pdfetch

class Reprint < WWW::Mechanize::File    
end


module Pdfetch::Controllers

  class Index < R '/'
    def get
      redirect "http://code.google.com/p/pdfetch/"
    end
  end
  
  class Static < R '/(\d+)\.pdf$'         
    def get(id)
      @pmid = id.to_s
      @headers['Content-Type'] = "application/pdf"
      @headers['X-Sendfile'] = "#{Dir.getwd}/#{id}.pdf"
    end
  end 

  class Fetch < R '/fetch/(\d+)$'    
    def get(id)
      @pmid = id.to_s
      @uri = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=#{id}&retmode=ref&cmd=prlinks"
      success = false
      begin
        if File.exist?("#{id}.pdf")
          success = true
        else
          m = WWW::Mechanize.new
          # set the mechanize pluggable parser for pdf files to the empty class Reprint, as a way to check for it later
          m.pluggable_parser.pdf = Reprint
          p = m.get(@uri)
          finders = Pdfetch::Finders.new
          for finder in finders.public_methods(false).sort
            break if page = finders.send(finder.to_sym, m,p)
          end
          if page.kind_of? Reprint
            page.save_as("#{id}.pdf")
            success = true
          end
        end
        raise unless success
        puts "** fetching of reprint #{id} succeeded (or already in library)"
        puts
        render :success
      rescue
        puts "** fetching of reprint #{id} failed"
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
        script "function gotouri(){location.href=\"#{@uri}\";} function gotopdf(){location.href=\"/#{@pmid}.pdf\";} function goback(){window.history.back()} function waitngoback(){window.setTimeout(goback(),3000);}", :type => 'text/javascript'
      end
      self << yield
    end
  end

  def success
    body :onload => 'gotopdf()' do nil end
  end

  def failure
    body :onload => 'gotouri()' do nil end
  end

end


class Pdfetch::Finders

  def generic(m,p)
    begin
      page = m.click p.links.with.text(/pdf|full[\s-]?text|reprint/i).and.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'generic' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def nature_review(m,p)
    begin
      page = m.click p.frames.with.name(/navbar/i)
      page = m.click page.links.with.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'nature review' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def springer_link(m,p)    
    begin
      page = m.click p.links.with.href(/fulltext.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'springer link' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def humana_press(m,p)
    begin
      page = m.click p.links.with.href(/task=readnow/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'humana press' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def wiley(m,p)
    begin
      page = m.click p.links.with.text(/pdf/i).and.href(/pdfstart/i)
      page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'wiley' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def science_direct(m,p)
    begin
      page = m.click p.links.with.text(/sciencedirect/i).and.href(/sciencedirect/i)
      page = m.click page.links.with.text(/pdf/i).and.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'science direct' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end          

  def jbc(m,p)
    begin
      page = m.click p.links.with.text(/pdf/i).and.href(/reprint/i)
      page = m.click page.frames.with.name(/reprint/i)
      page = m.click page.links.with.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'jbc' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end
         
  def nature(m,p)
    begin
      page = m.click p.links.with.text(/full text/i).and.href(/full/i)
      page = m.click page.links.with.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'nature' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def unknown(m,p)
    begin
      page = m.click p.frames.with.name(/reprint/i)
      page = m.click page.links.with.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'unknown' parser..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

end
