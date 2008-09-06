#!/usr/bin/env ruby

## pdfetch
## v0.5
## 2007-11-26
##
## Copyright (c) 2006-2007, Edoardo "Dado" Marcora, Ph.D.
## <http://marcora.caltech.edu/>
##
## Released under the MIT license
## <http://www.opensource.org/licenses/mit-license.php>
##
## --------------------------------------------------------------------
##
## PDFetch is a simple web server application that automagically
## fetches the PDF reprint of a PubMed article given its PMID and
## stores it locally in the directory where it is run from.
##
## --------------------------------------------------------------------

require 'rubygems'
require 'sinatra'
require 'mechanize'
require 'bio'

def __DIR__
  return File.dirname(File.expand_path(__FILE__))
end

configure do
  set_option :public, __DIR__
end

get '/' do
  redirect 'http://code.google.com/p/pdfetch'
end

get '/fetch' do
  pmid = nil
  url = params[:url]
  id = params[:id]
  unless id and url
    throw :halt, [400, 'required request params id and url are missing']
  end
  url.strip!
  id.strip!
  case id
  when /^10\.\S+\/\S+$/
    doi = id
    pmids = Bio::PubMed.search('"'+doi+'"[DOI]')
    if pmids.length == 1
      temp_pmid = pmids.first
      record = Bio::MEDLINE.new(Bio::PubMed.query(temp_pmid))
      if doi.include? record.doi or record.doi.include? doi
        pmid = temp_pmid
      else
        throw :halt, [404, 'cannot fetch article with doi:'+doi]
      end
    end
  when /^\d+$/
    pmid = id
  else
    redirect url
  end
  if pmid
    if fetch_reprint(pmid, url)
      redirect "/#{pmid}.pdf"
    elsif fetch_reprint(pmid)
      redirect "/#{pmid}.pdf"
    else
      redirect url
    end
  else
    redirect url
  end
end

def fetch_reprint(pmid, url=nil)
  reprint_is_in_dir = false
  reprint_path = "#{__DIR__}/#{pmid}.pdf"
  if File.exists?(reprint_path)
    reprint_is_in_dir = true
  else
    url ||= "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=#{pmid}&retmode=ref&cmd=prlinks"
    begin
      m = WWW::Mechanize.new
      # set the mechanize pluggable parser for pdf files to the empty class Reprint, as a way to check for it later
      m.pluggable_parser.pdf = Reprint
      p = m.get(url)
      puts "Fetching reprint of article #{pmid} at <#{p.uri}>..."
      # save as reprint if url points directly to a pdf
      if p.kind_of? Reprint
        p.save_as(reprint_path)
        reprint_is_in_dir = true
      else
        finders = Finders.new
        # loop through all finders until it finds one that return the pdf reprint
        for finder in finders.public_methods(false).sort
          break if page = finders.send(finder.to_sym, m,p) and page.kind_of? Reprint
        end
        # try pubmedcentral if finders did not work!
        unless page.kind_of? Reprint
          page = m.get("http://www.pubmedcentral.nih.gov/picrender.fcgi?pubmedid=#{pmid}&blobtype=pdf")
        end
        # save as reprint if pdf
        if page.kind_of? Reprint
          page.save_as(reprint_path)
          reprint_is_in_dir = true
        end
      end
    rescue
      reprint_is_in_dir = false
    end
  end
  return reprint_is_in_dir
end

class Reprint < WWW::Mechanize::File
  # empty class to use as Mechanize pluggable parser for pdf files
end

class Finders
  # Finders are functions used to find the pdf reprint off a publisher's website.
  # Pass a finder the mechanize agent (m) and the pubmed linkout page (p), and
  # it will return either the pdf reprint or nil.

  def nature_doi_finder(m,p)
    # http://www.nature.com/doifinder/...
    # goto nature
    if p.uri.to_s =~ /nature\.com\/doifinder\/\S+/i
      p = m.click p.links.with.text(/^full text$/i)
      return nature(m,p)
    end
  end

  def elsevier_linking_hub(m,p)
    # http://linkinghub.elsevier.com/retrieve/...
    # goto science_direct
    if p.uri.to_s =~ /linkinghub\.elsevier\.com/i
      p = m.click p.links.with.text(/sciencedirect/i).and.href(/sciencedirect/i)
      return science_direct(m,p)
    end
  end

  def science_direct(m,p)
    # http://www.sciencedirect.com/.../sdarticle.pdf
    if p.uri.to_s =~ /sciencedirect\.com/i
      page = m.get(p.at('body').inner_html.scan(/http:\/\/.*sdarticle.pdf/i).first)
      return page
    end
  end

  def pubmed_central(m,p)
    # http://www.pubmedcentral.nih.gov/articlerender.fcgi?artid=1698864&rendertype=abstract => http://www.pubmedcentral.nih.gov/picrender.fcgi?artid=1698864&blobtype=pdf
    if p.uri.to_s =~ /pubmedcentral\.nih\.gov/i
      page = m.get p.uri.to_s.gsub(/\/articlerender\.fcgi\?artid=(\d+)\S*$/i, '/picrender.fcgi?artid=\1&blobtype=pdf')
      return page
    end
  end

  def springer_link(m,p)
    # http://www.springerlink.com/content/p440667321125310/?p=eee8d594329c4374810fc9bcb55a47ce&pi=1 =>
    # http://www.springerlink.com/content/p440667321125310/fulltext.pdf
    if p.uri.to_s =~ /springerlink\.com/i
      page = m.get p.uri.to_s.gsub(/\/content\/(\w+)\/\S*$/i, '/content/\1/fulltext.pdf')
      return page
    end
  end

  def wiley_interscience(m,p)
    if p.uri.to_s =~ /interscience\.wiley\.com\/cgi-bin\/\w+\/(\d+)\//i
      # http://www3.interscience.wiley.com/cgi-bin/abstract/114803237/ABSTRACT => http://www3.interscience.wiley.com/cgi-bin/fulltext/114803237/PDFSTART
      # page = m.get p.uri.to_s.gsub(/\/cgi-bin\/\w+\/(\d+)\/\S*$/i, '/cgi-bin/fulltext/\1/PDFSTART')
      # page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      ## => http://download.interscience.wiley.com/cgi-bin/fulltext?ID=120846700&mode=pdf
      id = p.uri.to_s.scan(/\/cgi-bin\/\w+\/(\d+)\//i).first.first
      page = m.get "http://download.interscience.wiley.com/cgi-bin/fulltext?ID=#{id}&mode=pdf"
      return page
    elsif p.uri.to_s =~ /interscience\.wiley\.com\/journal\/\d+\/abstract/i
      # http://www3.interscience.wiley.com/journal/114803237/abstract => http://www3.interscience.wiley.com/cgi-bin/fulltext/114803237/PDFSTART
      # page = m.get p.uri.to_s.gsub(/\/journal\/(\d+)\/abstract$/i, '/cgi-bin/fulltext/\1/PDFSTART')
      # page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      ## => http://download.interscience.wiley.com/cgi-bin/fulltext?ID=120846700&mode=pdf
      id = p.uri.to_s.scan(/\/journal\/(\d+)\/abstract/i).first.first
      page = m.get "http://download.interscience.wiley.com/cgi-bin/fulltext?ID=#{id}&mode=pdf"
      return page
    end
  end

  def nature(m,p)
    # http://www.nature.com/neuro/journal/v10/n10/abs|full/nn1974.html => http://www.nature.com/neuro/journal/v10/n10/pdf/nn1974.pdf
    # http://www.nature.com/neuro/journal/vaop/ncurrent/abs|full/nn2013.html => http://www.nature.com/neuro/journal/vaop/ncurrent/pdf/nn2013.pdf
    # http://www.nature.com/news/2008/080806/full/454682a.html => http://www.nature.com/news/2008/080806/pdf/454682a.pdf
    if p.uri.to_s =~ /nature\.com/i and not p.uri.to_s =~ /nature\.com\/doifinder/i
      # page = m.get p.uri.to_s.gsub(/\/journal\/v(\w+)\/n(\w+)\/(?:abs|full)\/([\w\.]+).html\S*$/i, '/journal/v\1/n\2/pdf/\3.pdf')
      page = m.get p.uri.to_s.gsub(/nature\.com\/(\S+)\/(?:abs|full)\/([\w\.]+).html\S*$/i, 'nature.com/\1/pdf/\2.pdf')
      return page
    end
  end

  def biomedcentral(m,p)
    # http://www.biomedcentral.com/1471-2121/8/22 => http://www.biomedcentral.com/content/pdf/1471-2121-8-22.pdf
    if p.uri.to_s =~ /biomedcentral\.com/i
      page = m.get p.uri.to_s.gsub(/\/(\w+-\w+)\/(\w+)\/(\w+)$/i, '/content/pdf/\1-\2-\3.pdf')
      return page
    end
  end

  def mit_press_journals_and_blackwell_synergy(m,p)
    #  http://www.mitpressjournals.org/doi/abs/10.1162/jocn.2007.19.8.1231 => http://www.mitpressjournals.org/doi/pdf/10.1162/jocn.2007.19.8.1231
    if p.uri.to_s =~ /mitpressjournals\.org/i or p.uri.to_s =~ /blackwell-synergy\.com/i or p.uri.to_s =~ /annualreviews\.org/i
      page = m.get p.uri.to_s.gsub(/\/doi\/abs\/(\S+)$/i, '/doi/pdf/\1')
      return page
    end
  end

  def highwire_press_journals_oxford_journals_and_science(m,p)
    # http://www.pnas.org/cgi/content/abstract/100/16/9578 =>
    # http://www.pnas.org/cgi/reprint/100/16/9578.pdf
    # http://www.pnas.org/content/105/25/8778.full/abstract =>
    # http://www.pnas.org/content/105/25/8778.full.pdf =>
    if p.uri.to_s =~ /\/cgi\/content\/\w+\/(\S+)$/i
      page = m.get p.uri.to_s.gsub(/\/cgi\/content\/\w+\/(\S+)$/i, '/cgi/reprint/\1.pdf')
      unless page.kind_of? Reprint
        page = m.get p.uri.to_s.gsub(/\/cgi\/content\/\w+\/(\S+)$/i, '/cgi/rapidpdf/\1.pdf')
      end
      return page
    elsif p.uri.to_s =~ /\/cgi\/(reprint|rapidpdf)\/(\S+)$/i
      page = m.get p.uri.to_s.gsub(/\/cgi\/(reprint|rapidpdf)\/(\S+)$/i, '/cgi/\1/\2.pdf')
      return page
    elsif p.uri.to_s =~ /\/content\/(\S+)\/(\d+)(?:\.full|\.abstract|$)/i
      page = m.get p.uri.to_s.gsub(/\/content\/(\S+)\/(\d+)(?:\.full|\.abstract|$)/i, '/content/\1/\2.full.pdf')
      return page
    end
  end

  def acs(m,p)
    # http://pubs.acs.org/cgi-bin/abstract.cgi/acbcct/2008/3/i08/abs/cb8000793.html =>
    # http://pubs.acs.org/cgi-bin/article.cgi/acbcct/2008/3/i08/pdf/cb8000793.pdf
    if p.uri.to_s =~ /acs\.org/i
      page = m.get p.uri.to_s.gsub(/acs\.org\/cgi-bin\/\w+\.cgi\/(\S+)\/(?:abs|html)\/([\w\.]+)\.html\S*$/i, 'acs.org/cgi-bin/article.cgi/\1/pdf/\2.pdf')
      return page
    end
  end

  def biochemj(m,p)
    # http://www.biochemj.org/bj/414/0327/bj4140327.htm => http://www.biochemj.org/bj/414/0327/4140327.pdf
    if p.uri.to_s =~ /biochemj\.org/i
      page = m.click p.links.with.text(/^PDF$/i)
      return page
    end
  end

  def plos_one(m, p)
    # http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0003059 =>
    # http://www.plosone.org/article/fetchObjectAttachment.action?uri=info%3Adoi%2F10.1371%2Fjournal.pone.0003059&representation=PDF
    if p.uri.to_s =~ /plosone\.org/i
      page = m.get p.uri.to_s.gsub(/plosone\.org\/article\/info(\S+)$/i, '/plosone.org/fetchObjectAttachment.action?representation=PDF&uri=info\1')
      return page
    end
  end

  def plos_journals(m, p)
    if p.uri.to_s =~ /plosjournals\.org/i
      page = m.click p.links.with.text(/^PDF.+-.+Small\S+(.+)$/i)
      return page
    end
  end

end
