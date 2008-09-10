#!/usr/bin/env ruby

## pdfetch
## v0.6
## 2008-03-29
##
## Copyright (c) 2006-2008, Edoardo "Dado" Marcora, Ph.D.
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
require 'json'

def __DIR__
  return File.dirname(File.expand_path(__FILE__))
end

configure do
  set_option :public, __DIR__
end

post '/' do
  raise unless @request.content_type == 'application/pdf'
  filename = "#{`uuidgen`.strip}.pdf" # FIXME: this requires unix on the server!!!
  File.open("#{__DIR__}/#{filename}", "w") { |file| file.write(@request.body.read) }
  filename
end

get '/pdf_urls' do
  raise unless url = params['url']
  pmid = nil
  doi = nil
  case id = params['id']
  when /\d+/
    puts 'pmid'
  when /\S+\/S+/
    puts 'doi'
  else
    puts 'no id'
  end
  m = WWW::Mechanize.new
  p = m.get(url)
  puts p.uri.to_s

  pdf_urls = []
  finders = Finders.new

  for finder in finders.public_methods(false).sort
    pdf_urls << finders.send(finder.to_sym, m, p)
  end

  if p.uri.to_s =~ /ncbi\.nlm\.nih\.gov\/pubmed\/(\d+)/i
    pmid = Regexp.last_match(1)
  end

  if pmid
    pdf_urls << "http://www.pubmedcentral.nih.gov/picrender.fcgi?pubmedid=#{pmid}&blobtype=pdf"
  end

  pdf_urls = pdf_urls.flatten.compact.uniq
  pdf_urls.to_json
end

class Finders
  # Finders are functions used to find the url of the pdf reprint.
  # Pass a finder the mechanize agent (m) and any web page (pubmed, pmc, publisher's website)
  # associated with a pdf reprint (p), and it will return either the pdf url or nil.

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
      pdf_url = p.at('body').inner_html.scan(/http:\/\/.*sdarticle.pdf/i).first
      return pdf_url
    end
  end

  def pubmed_central(m,p)
    # http://www.pubmedcentral.nih.gov/articlerender.fcgi?artid=1698864&rendertype=abstract => http://www.pubmedcentral.nih.gov/picrender.fcgi?artid=1698864&blobtype=pdf
    if p.uri.to_s =~ /pubmedcentral\.nih\.gov/i
      pdf_url = p.uri.to_s.gsub(/\/articlerender\.fcgi\?artid=(\d+)\S*$/i, '/picrender.fcgi?artid=\1&blobtype=pdf')
      return pdf_url
    end
  end

  def springer_link(m,p)
    # http://www.springerlink.com/content/p440667321125310/?p=eee8d594329c4374810fc9bcb55a47ce&pi=1 =>
    # http://www.springerlink.com/content/p440667321125310/fulltext.pdf
    if p.uri.to_s =~ /springerlink\.com/i
      pdf_url = p.uri.to_s.gsub(/\/content\/(\w+)\/\S*$/i, '/content/\1/fulltext.pdf')
      return pdf_url
    end
  end

  def wiley_interscience(m,p)
    if p.uri.to_s =~ /interscience\.wiley\.com\/cgi-bin\/\w+\/(\d+)\//i
      # http://www3.interscience.wiley.com/cgi-bin/abstract/114803237/ABSTRACT => http://www3.interscience.wiley.com/cgi-bin/fulltext/114803237/PDFSTART
      # page = m.get p.uri.to_s.gsub(/\/cgi-bin\/\w+\/(\d+)\/\S*$/i, '/cgi-bin/fulltext/\1/PDFSTART')
      # page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      ## => http://download.interscience.wiley.com/cgi-bin/fulltext?ID=120846700&mode=pdf
      id = p.uri.to_s.scan(/\/cgi-bin\/\w+\/(\d+)\//i).first.first
      pdf_url = "http://download.interscience.wiley.com/cgi-bin/fulltext?ID=#{id}&mode=pdf"
      return pdf_url
    elsif p.uri.to_s =~ /interscience\.wiley\.com\/journal\/\d+\/abstract/i
      # http://www3.interscience.wiley.com/journal/114803237/abstract => http://www3.interscience.wiley.com/cgi-bin/fulltext/114803237/PDFSTART
      # page = m.get p.uri.to_s.gsub(/\/journal\/(\d+)\/abstract$/i, '/cgi-bin/fulltext/\1/PDFSTART')
      # page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      ## => http://download.interscience.wiley.com/cgi-bin/fulltext?ID=120846700&mode=pdf
      id = p.uri.to_s.scan(/\/journal\/(\d+)\/abstract/i).first.first
      pdf_url =  "http://download.interscience.wiley.com/cgi-bin/fulltext?ID=#{id}&mode=pdf"
      return pdf_url
    end
  end

  def nature(m,p)
    # http://www.nature.com/neuro/journal/v10/n10/abs|full/nn1974.html => http://www.nature.com/neuro/journal/v10/n10/pdf/nn1974.pdf
    # http://www.nature.com/neuro/journal/vaop/ncurrent/abs|full/nn2013.html => http://www.nature.com/neuro/journal/vaop/ncurrent/pdf/nn2013.pdf
    # http://www.nature.com/news/2008/080806/full/454682a.html => http://www.nature.com/news/2008/080806/pdf/454682a.pdf
    if p.uri.to_s =~ /nature\.com/i and not p.uri.to_s =~ /nature\.com\/doifinder/i
      # pdf_url =  p.uri.to_s.gsub(/\/journal\/v(\w+)\/n(\w+)\/(?:abs|full)\/([\w\.]+).html\S*$/i, '/journal/v\1/n\2/pdf/\3.pdf')
      pdf_url = p.uri.to_s.gsub(/nature\.com\/(\S+)\/(?:abs|full)\/([\w\.]+).html\S*$/i, 'nature.com/\1/pdf/\2.pdf')
      return pdf_url
    end
  end

  def biomedcentral(m,p)
    # http://www.biomedcentral.com/1471-2121/8/22 => http://www.biomedcentral.com/content/pdf/1471-2121-8-22.pdf
    if p.uri.to_s =~ /biomedcentral\.com/i
      pdf_url = t p.uri.to_s.gsub(/\/(\w+-\w+)\/(\w+)\/(\w+)$/i, '/content/pdf/\1-\2-\3.pdf')
      return pdf_url
    end
  end

  def mit_press_journals_and_blackwell_synergy(m,p)
    #  http://www.mitpressjournals.org/doi/abs/10.1162/jocn.2007.19.8.1231 => http://www.mitpressjournals.org/doi/pdf/10.1162/jocn.2007.19.8.1231
    if p.uri.to_s =~ /mitpressjournals\.org/i or p.uri.to_s =~ /blackwell-synergy\.com/i or p.uri.to_s =~ /annualreviews\.org/i
      pdf_url =  p.uri.to_s.gsub(/\/doi\/abs\/(\S+)$/i, '/doi/pdf/\1')
      return pdf_url
    end
  end

  def highwire_press_journals_oxford_journals_and_science(m,p)
    # http://www.pnas.org/cgi/content/abstract/100/16/9578 =>
    # http://www.pnas.org/cgi/reprint/100/16/9578.pdf
    # http://www.pnas.org/content/105/25/8778.full/abstract =>
    # http://www.pnas.org/content/105/25/8778.full.pdf =>
    if p.uri.to_s =~ /\/cgi\/content\/\w+\/(\S+)$/i
      pdf_urls = []
      pdf_urls << p.uri.to_s.gsub(/\/cgi\/content\/\w+\/(\S+)$/i, '/cgi/reprint/\1.pdf')
      pdf_urls << p.uri.to_s.gsub(/\/cgi\/content\/\w+\/(\S+)$/i, '/cgi/rapidpdf/\1.pdf')
      return pdf_urls
    elsif p.uri.to_s =~ /\/cgi\/(reprint|rapidpdf)\/(\S+)$/i
      pdf_url =  p.uri.to_s.gsub(/\/cgi\/(reprint|rapidpdf)\/(\S+)$/i, '/cgi/\1/\2.pdf')
      return pdf_url
    elsif p.uri.to_s =~ /\/content\/(\S+)\/(\d+)(?:\.full|\.abstract|$)/i
      pdf_url = p.uri.to_s.gsub(/\/content\/(\S+)\/(\d+)(?:\.full|\.abstract|$)/i, '/content/\1/\2.full.pdf')
      return pdf_url
    end
  end

  def acs(m,p)
    # http://pubs.acs.org/cgi-bin/abstract.cgi/acbcct/2008/3/i08/abs/cb8000793.html =>
    # http://pubs.acs.org/cgi-bin/article.cgi/acbcct/2008/3/i08/pdf/cb8000793.pdf
    if p.uri.to_s =~ /acs\.org/i
      pdf_url =  p.uri.to_s.gsub(/acs\.org\/cgi-bin\/\w+\.cgi\/(\S+)\/(?:abs|html)\/([\w\.]+)\.html\S*$/i, 'acs.org/cgi-bin/article.cgi/\1/pdf/\2.pdf')
      return pdf_url
    end
  end

  def biochemj(m,p)
    # http://www.biochemj.org/bj/414/0327/bj4140327.htm => http://www.biochemj.org/bj/414/0327/4140327.pdf
    if p.uri.to_s =~ /biochemj\.org/i
      pdf_url = p.links.with.text(/^PDF$/i).first.href
      return pdf_url
    end
  end

  def plos_one(m, p)
    # http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0003059 =>
    # http://www.plosone.org/article/fetchObjectAttachment.action?uri=info%3Adoi%2F10.1371%2Fjournal.pone.0003059&representation=PDF
    if p.uri.to_s =~ /plosone\.org/i
      pdf_url = p.uri.to_s.gsub(/plosone\.org\/article\/info(\S+)$/i, '/plosone.org/fetchObjectAttachment.action?representation=PDF&uri=info\1')
      return pdf_url
    end
  end

  def plos_journals(m, p)
    if p.uri.to_s =~ /plosjournals\.org/i
      pdf_url =  p.links.with.text(/^PDF.+-.+Small\S+(.+)$/i).first.href
      return pdf_url
    end
  end

end
