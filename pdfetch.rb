## pdfetch
## v0.4
## 2007-06-29
##
## Copyright (c) 2006, Edoardo "Dado" Marcora, Ph.D.
## <http://marcora.caltech.edu/>
##
## Released under the MIT license
## <http://www.opensource.org/licenses/mit-license.php>
##
## --------------------------------------------------------------------
##
## This is a Camping web app that automagically fetches a PDF reprint
## of a PubMed article given its PMID.
##
## --------------------------------------------------------------------

require 'uri'

require 'camping'
require 'mechanize'

Camping.goes :Pdfetch

class Reprint < WWW::Mechanize::File
  # empty class to use as Mechanize pluggable parser for pdf files
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
        if File.exist?("#{id}.pdf") # bypass finders if pdf reprint already stored locally
          success = true
        else
          m = WWW::Mechanize.new
          # set the mechanize pluggable parser for pdf files to the empty class Reprint, as a way to check for it later
          m.pluggable_parser.pdf = Reprint
          p = m.get(@uri)
          @uri = p.uri
          finders = Pdfetch::Finders.new
          # loop through all finders until it finds one that return the pdf reprint
          for finder in finders.public_methods(false).sort
            break if page = finders.send(finder.to_sym, m,p)
          end
          if page.kind_of? Reprint
            page.save_as("#{id}.pdf")
            success = true
          end
        end
        raise unless success
        puts "** fetching of reprint #{id} succeeded"
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
  # Finders are functions used to find the pdf reprint off a publisher's website.
  # Pass a finder the mechanize agent (m) and the pubmed linkout page (p), and
  # it will return either the pdf reprint or nil.

  def zeneric(m,p) # this finder has been renamed 'zeneric' instead of 'generic' to have it called last (as last resort)
    begin
      page = m.click p.links.with.text(/pdf|full[\s-]?text|reprint/i).and.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'generic' finder..."
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
        puts "** fetching reprint using the 'springer link' finder..."
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
        puts "** fetching reprint using the 'humana press' finder..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def blackwell_synergy(m,p)
    begin
      return nil unless p.uri.to_s =~ /\/doi\/abs\//i
      page = m.get(p.uri.to_s.sub('abs', 'pdf'))
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'blackwell synergy' finder..."
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
        puts "** fetching reprint using the 'wiley' finder..."
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
      return nil unless p.uri.to_s =~ /sciencedirect/i
      page = m.get(p.at('body').inner_html.scan(/http:\/\/.*sdarticle.pdf/).first)
#      page = m.click p.links.with.text(/sciencedirect/i).and.href(/sciencedirect/i)
#      page = m.click page.links.with.href(/sdarticle\.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'science direct' finder..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def ingenta_connect(m,p)
    begin
      page = m.click p.links.with.href(/mimetype=.*pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'ingenta connect' finder..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def cell_press(m,p)
    begin
      page = m.click p.links.with.text(/cell|cancer cell|developmental cell|molecular cell|neuron|structure|immunity|chemistry.+biology|cell metabolism|current biology/i).and.href(/cancercell|cell|developmentalcell|immunity|molecule|structure|current-biology|cellmetabolism|neuron|chembiol/i)
      uid = /uid=(.+)/i.match(page.uri.to_s)
      if uid
        re = Regexp.new(uid[1])
        page = m.click page.links.with.text(/pdf/i).and.href(re)
      else
        page = m.click page.links.with.text(/pdf \(\d+K\)/i).and.href(/\.pdf$/i)
      end
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'cell press' finder..."
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
        puts "** fetching reprint using the 'jbc' finder..."
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
      return nil if p.uri.to_s =~ /sciencedirect/i # think of a better way to skip this finder for sciencedirect reprints!
      page = m.click p.links.with.text(/full text/i).and.href(/full/i)
      page = m.click page.links.with.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'nature' finder..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def nature_reviews(m,p)
    begin
      page = m.click p.frames.with.name(/navbar/i)
      page = m.click page.links.with.href(/.pdf$/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'nature reviews' finder..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

  def pubmed_central(m,p)
    begin
      # raise unless p.uri =~ /pubmedcentral/i
      page = m.click p.links.with.text(/pdf/i).and.href(/blobtype=pdf/i)
      if page.kind_of? Reprint
        puts "** fetching reprint using the 'pubmed central' finder..."
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
        puts "** fetching reprint using the 'unknown' finder..."
        return page
      else
        return nil
      end
    rescue
      return nil
    end
  end

end
