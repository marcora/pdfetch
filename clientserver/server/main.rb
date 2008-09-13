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
require 'logger'
require 'uri'
require 'mechanize'
require 'json'

def __DIR__
  return File.dirname(File.expand_path(__FILE__))
end

configure do
  set_option :public, __DIR__
end

helpers do
  def is_valid_url(url)
    begin
      uri = URI.parse(url)
      if uri.class == URI::HTTP
        return true
      else
        return false
      end
    rescue URI::InvalidURIError
      return false
    end
  end
end

post '/reprints' do
  # Take pdf, store it to filesystem or datastore, and return reprint id
  raise unless @request.content_type == "application/pdf" # TODO: check if pdf and size of pdf
  filename = "#{`uuidgen`.strip}.pdf"
  File.open("#{__DIR__}/reprints/#{filename}", "w") { |file| file.write(@request.body.read) }
  filename
end

get '/pdf_urls' do
  # Take page url and return a list of pdf urls where pdf associated to page can be found
  raise unless url = params['url'] and is_valid_url(url)
  pdf_urls = []
  pmid, pmcid, doi = nil

  case id = params['id']
  when /\d+/
    pmid = id
  when /PMC(\d+)/i
    pmcid = Regexp.last_match(1)
  when /\S+\/S+/
    doi = id
  end

  begin
    # load url into mechanize page
    m = WWW::Mechanize.new; m.read_timeout = 10
    p = m.get(url) rescue Net::HTTPUnauthorized

    # init pmid from url if not set
    if p.uri.to_s =~ /ncbi\.nlm\.nih\.gov\/pubmed\/(\d+)/i
      pmid = Regexp.last_match(1) unless pmid
    elsif p.uri.to_s =~ /ncbi\.nlm\.nih\.gov\/sites\/entrez\?db=pubmed&cmd=search&term=(\d+)/i
      pmid = Regexp.last_match(1) unless pmid
    end

    # init pmcid from url if not set
    if p.uri.to_s =~ /pubmedcentral\.nih\.gov\/articlerender\.fcgi\?\S*&?artid=(\d+)&?\S*$/i
      pmcid = Regexp.last_match(1) unless pmcid
    end

    # use elink url if pmid
    # TODO: use elink url if pmcid/doi?!?
    if pmid
      elink_url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=#{pmid}&retmode=ref&cmd=prlinks"
      elink_p = m.get(elink_url) rescue Net::HTTPUnauthorized
      p = elink_p unless elink_p.uri.to_s =~ /ncbi\.nlm\.nih\.gov\/pubmed\/(\d+)/i
    end

    # if page is pdf return its url
    if p.content_type == 'application/pdf'
      return [p.uri.to_s].to_json
    end

    # loop through all finders
    finders = Finders.new
    for finder in finders.public_methods(false).sort
      begin
        pdf_urls << finders.send(finder.to_sym, m,p)
      rescue Timeout::Error
        next
      rescue
        next
      end
    end

    # last, add pmc url if pmcid/pmid/doi
    if pmcid
      pdf_urls << "http://www.pubmedcentral.nih.gov/picrender.fcgi?artid=#{pmcid}&blobtype=pdf"
    elsif pmid
      pdf_urls << "http://www.pubmedcentral.nih.gov/picrender.fcgi?pubmedid=#{pmid}&blobtype=pdf"
    elsif doi
      pdf_urls << "http://www.pubmedcentral.nih.gov/picrender.fcgi?doi=#{URI.escape(doi)}&blobtype=pdf"
    end
  rescue Timeout::Error
    raise
  rescue
    raise
  end
  pdf_urls = pdf_urls.flatten.compact.uniq
  puts pdf_urls
  pdf_urls.to_json
end

post '/pdf_notfound' do
  # Take url of page for which associated pdf cannot be found and append it to log
  raise unless url = @request.body.read.to_s and is_valid_url(url)
  log = Logger.new('pdf_notfound.log', 'monthly')
  log << "#{url}\n"
  log.close
end


class Finders # a finder take a mechanize agent (m) and page (p) and return either the url of the pdf associated with page or nil

  def nature_doi_finder(m,p)
    # http://www.nature.com/doifinder/...
    # goto nature
    if p.uri.to_s =~ /nature\.com\/doifinder\/\S+/i
      p = m.click p.links.with.text(/Full\s+Text/) rescue Net::HTTPUnauthorized
      return nature(m,p)
    end
  end

  def elsevier_linking_hub(m,p)
    # http://linkinghub.elsevier.com/retrieve/...
    # goto science_direct
    if p.uri.to_s =~ /linkinghub\.elsevier\.com/i
      p = m.click p.links.with.text(/sciencedirect/i).and.href(/sciencedirect/i) rescue Net::HTTPUnauthorized
      return science_direct(m,p)
    end
  end

  def science_direct(m,p)
    # http://www.sciencedirect.com/.../sdarticle.pdf in tab
    if p.uri.to_s =~ /sciencedirect\.com/i
      pdf_url = p.at("div[@class=tabUnselectedOuter]/../../td").inner_html.scan(/href="(http:\/\/\S+\/sdarticle\.pdf\S*)"/i).first.first rescue nil
      return pdf_url
    end
  end

  def springer_link(m,p)
    # http://www.springerlink.com/content/p440667321125310/?p=eee8d594329c4374810fc9bcb55a47ce&pi=1 =>
    # http://www.springerlink.com/content/p440667321125310/fulltext.pdf
    if p.uri.to_s =~ /springerlink\.com/i
      pdf_url = p.uri.to_s.gsub(/\/content\/(\w+)(?:\/|$)\S*$/i, '/content/\1/fulltext.pdf')
      return pdf_url
    end
  end

  def lww(m,p)
    # http://www.jaacap.com/pt/re/jaacap/abstract.00004583-200807000-00004.htm => http://www.jaacap.com/pt/re/jaacap/pdfhandler.00004583-200807000-00004.pdf
    if p.uri.to_s =~ /\/(?:abstract|fulltext)\.\S+\.htm/i
      pdf_url = p.uri.to_s.gsub(/\/(?:abstract|fulltext)\.(\S+)\.htm\S*$/, '/pdfhandler.\1.pdf')
      return pdf_url
    end
  end

  def wiley_interscience(m,p)
    if p.uri.to_s =~ /interscience\.wiley\.com\/cgi-bin\/\w+\/(\d+)\//i
      # http://www3.interscience.wiley.com/cgi-bin/abstract/114803237/ABSTRACT => http://www3.interscience.wiley.com/cgi-bin/fulltext/114803237/PDFSTART
      # page = m.get p.uri.to_s.gsub(/\/cgi-bin\/\w+\/(\d+)\/\S*$/i, '/cgi-bin/fulltext/\1/PDFSTART')
      # page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      ## => http://download.interscience.wiley.com/cgi-bin/fulltext?ID=120846700&mode=pdf
      id = p.uri.to_s.scan(/\/cgi-bin\/\w+\/(\d+)\//i).first.first rescue nil
      if id
        pdf_url = "http://download.interscience.wiley.com/cgi-bin/fulltext?ID=#{id}&mode=pdf"
      else
        pdf_url = nil
      end
      return pdf_url
    elsif p.uri.to_s =~ /interscience\.wiley\.com\/journal\/\d+\/abstract/i
      # http://www3.interscience.wiley.com/journal/114803237/abstract => http://www3.interscience.wiley.com/cgi-bin/fulltext/114803237/PDFSTART
      # page = m.get p.uri.to_s.gsub(/\/journal\/(\d+)\/abstract$/i, '/cgi-bin/fulltext/\1/PDFSTART')
      # page = m.click page.frames.with.name(/main/i).and.src(/mode=pdf/i)
      ## => http://download.interscience.wiley.com/cgi-bin/fulltext?ID=120846700&mode=pdf
      id = p.uri.to_s.scan(/\/journal\/(\d+)\/abstract/i).first.first rescue nil
      if id
        pdf_url =  "http://download.interscience.wiley.com/cgi-bin/fulltext?ID=#{id}&mode=pdf"
      else
        pdf_url =  nil
      end
      return pdf_url
    end
  end

  def nature(m,p)
    # http://www.nature.com/neuro/journal/v10/n10/abs|full/nn1974.html => http://www.nature.com/neuro/journal/v10/n10/pdf/nn1974.pdf
    # http://www.nature.com/neuro/journal/vaop/ncurrent/abs|full/nn2013.html => http://www.nature.com/neuro/journal/vaop/ncurrent/pdf/nn2013.pdf
    # http://www.nature.com/news/2008/080806/full/454682a.html => http://www.nature.com/news/2008/080806/pdf/454682a.pdf
    if p.uri.to_s =~ /nature\.com/i and not p.uri.to_s =~ /nature\.com\/doifinder/i
      pdf_url = p.uri.to_s.gsub(/nature\.com\/(\S+)\/(?:abs|full)\/([\w\-\.]+).html\S*$/i, 'nature.com/\1/pdf/\2.pdf')
      return pdf_url
    end
  end

  def biomedcentral(m,p)
    # http://www.biomedcentral.com/1471-2164/4/19 => http://www.biomedcentral.com/content/pdf/1471-2164-4-19.pdf
    # http://www.biomedcentral.com/1471-2164/4/19/abstract/
    if p.uri.to_s =~ /biomedcentral\.com/i
      pdf_url = p.uri.to_s.gsub(/biomedcentral\.com\/(\w+\-\w+)\/(\w+)\/(\w+)\/?\S*$/i, 'biomedcentral.com/content/pdf/\1-\2-\3.pdf')
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
    # http://www.pnas.org/cgi/content/full/100/16/9578 =>
    # http://www.pnas.org/cgi/content/abstract/100/16/9578 =>
    # http://www.pnas.org/cgi/reprint/100/16/9578.pdf
    #
    # http://www.pnas.org/content/105/25/8778.full/abstract =>
    # http://www.pnas.org/content/105/25/8778.full.pdf
    #
    # http://hmg.oxfordjournals.org/cgi/content/full/7/5/791 =>
    # http://hmg.oxfordjournals.org/cgi/reprint/7/5/791
    if p.uri.to_s =~ /\/cgi\/content\/\w+\/[\w\/;]+/i
      pdf_urls = []
      pdf_urls << p.uri.to_s.gsub(/\/cgi\/content\/\w+\/([\w\/;]+)/i, '/cgi/reprint/\1.pdf')
      pdf_urls << p.uri.to_s.gsub(/\/cgi\/content\/\w+\/([\w\/;]+)/i, '/cgi/reprint/\1')
      pdf_urls << p.uri.to_s.gsub(/\/cgi\/content\/\w+\/([\w\/;]+)/i, '/cgi/rapidpdf/\1.pdf')
      pdf_urls << p.uri.to_s.gsub(/\/cgi\/content\/\w+\/([\w\/;]+)/i, '/cgi/rapidpdf/\1')
      return pdf_urls
    elsif p.uri.to_s =~ /\/cgi\/(reprint|rapidpdf)\/[\w\/;]+/i
      pdf_url =  p.uri.to_s.gsub(/\/cgi\/(reprint|rapidpdf)\/([\w\/;]+)/i, '/cgi/\1/\2.pdf')
      return pdf_url
    elsif p.uri.to_s =~ /\/content\/\S+\/\d+(\.full|\.abstract|$)/i
      pdf_url = p.uri.to_s.gsub(/\/content\/([\w\/;]+)\/(\d+)(?:\.full|\.abstract|$)/i, '/content/\1/\2.full.pdf')
      return pdf_url
    end
  end

  def meta_press(m,p)
    # http://iospress.metapress.com/content/x1ed67v1uqumjv83/
    # http://iospress.metapress.com/content/x1ed67v1uqumjv83/fulltext.pdf
    if p.uri.to_s =~ /metapress\.com\/content\/\S+$/i
      pdf_url = p.uri.to_s.gsub(/metapress\.com\/content\/([^\s\/]+)\/?$/i, 'metapress.com/content/\1/fulltext.pdf')
      return pdf_url
    end
  end

  def acs(m,p)
    # http://pubs.acs.org/cgi-bin/abstract.cgi/acbcct/2008/3/i08/abs/cb8000793.html =>
    # http://pubs.acs.org/cgi-bin/article.cgi/acbcct/2008/3/i08/pdf/cb8000793.pdf
    if p.uri.to_s =~ /acs\.org/i
      pdf_url =  p.uri.to_s.gsub(/acs\.org\/cgi-bin\/(?:abstract|article)\.cgi\/([\w\/]+)(?:abs|html)\/([\w\.]+)\.html\S*$/i, 'acs.org/cgi-bin/article.cgi/\1pdf/\2.pdf')
      p = m.get(pdf_url) rescue Net::HTTPUnauthorized # FIXME: needed because of redirect, perhaps ffx extension should follow redirects
      return p.links.first.href rescue nil
    end
  end

  def portland_press(m,p)
    # http://www.biochemsoctrans.org/bst/029/0623/bst0290623.htm =>
    # http://www.biochemsoctrans.org/bst/029/0623/0290623.pdf
    if p.uri.to_s =~ /^http:\/\/([\w\.]+)\/(\w+)\/(\w+)\/(\w+)\/(\w+)\.htm$/i
      pdf_url =  p.uri.to_s.gsub(/^http:\/\/([\w\.]+)\/(\w+)\/(\w+)\/(\w+)\/(\w+)\.htm$/i, 'http://\1/\2/\3/\4/\5.pdf')
      id = p.uri.to_s.scan(/^http:\/\/[\w\.]+\/(\w+)\//i).first.first rescue nil
      if id
        pdf_url = pdf_url.gsub(id, "").gsub("//", "/#{id}/").sub("/#{id}/", "//")
      else
        pdf_url = nil
      end
      return pdf_url
    end
  end

  def liebertol_and_uchicago(m,p)
    # http://www.liebertonline.com/doi/abs|full/10.1089%2F10430340252899046 =>
    # http://www.liebertonline.com/doi/pdf/10.1089/10430340252899046
    #
    # http://www.expert-reviews.com/doi/abs|full/10.1586/14760584.4.3.281?url_ver=Z39.88-2003&rfr_id=ori:rid:crossref.org =>
    # http://www.expert-reviews.com/doi/pdf/10.1586/14760584.4.3.281
    if p.uri.to_s =~ /\/doi\/(abs|full)\/\S+$/i
      pdf_url =  p.uri.to_s.gsub(/\/doi\/(?:abs|full)\/([^\s\?]+)\S*$/i, '/doi/pdf/\1')
      return pdf_url
    end
  end

  def plos_one(m,p)
    # http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0003059 =>
    # http://www.plosone.org/article/fetchObjectAttachment.action?uri=info%3Adoi%2F10.1371%2Fjournal.pone.0003059&representation=PDF
    if p.uri.to_s =~ /(plosone|ploscompbiol)\.org/i
      pdf_url = p.uri.to_s.gsub(/(plosone|ploscompbiol)\.org\/article\/info(\S+)$/i, '/\1.org/fetchObjectAttachment.action?representation=PDF&uri=info\2')
      return pdf_url
    end
  end

  def plos_journals(m,p)
    # http://biology.plosjournals.org/perlserv/?request=get-document&doi=10.1371/journal.pbio.0060214 =>
    # http://biology.plosjournals.org/perlserv/?request=get-pdf&file=10.1371_journal.pbio.0060214-S.pdf
    if p.uri.to_s =~ /plosjournals\.org/i
      # pdf_url =  p.links.with.text(/^PDF.+-.+Small\S+(.+)$/i).first.href
      pdf_url = p.uri.to_s.gsub(/plosjournals\.org\/perlserv\/?(?:\S*)doi=(\S+)\/([^\s&]+)&?\S*$/i, 'plosjournals.org/perlserv/?request=get-pdf&file=\1_\2-S.pdf')
      p = m.get(pdf_url) rescue Net::HTTPUnauthorized # FIXME: needed because of redirect, perhaps ffx extension should follow redirects
      return p.uri.to_s
    end
  end

  def royal_society(m,p)
    # http://journals.royalsociety.org/content/gt4vph09ecy4f1f3/ =>
    # http://journals.royalsociety.org/content/gt4vph09ecy4f1f3/fulltext.pdf
    if p.uri.to_s =~ /royalsociety\.org/i
      pdf_url = p.uri.to_s.gsub(/royalsociety\.org\/content\/(\w+)\/?$/i, 'royalsociety.org/content/\1/fulltext.pdf')
      return pdf_url
    end
  end

  def jci(m,p)
    # http://www.jci.org/articles/view/36872 =>
    # http://www.pubmedcentral.nih.gov/picrender.fcgi?doi=10.1172/JCI36872&blobtype=pdf
    if p.uri.to_s =~ /jci\.org\/articles\/view\//i
      doi = p.uri.to_s.scan(/\/articles\/view\/(\w*\d+)\S*$/i).first.first rescue nil
      return nil unless doi
      unless doi =~ /^jci/i
        doi = 'JCI'+doi
      end
      doi.upcase!
      pdf_url = "http://www.pubmedcentral.nih.gov/picrender.fcgi?doi=10.1172/#{doi}&blobtype=pdf"
      return pdf_url
    end
  end

  def ecm(m,p)
    # http://www.ecmjournal.org/journal/papers/vol011/vol011a08.php =>
    # http://www.ecmjournal.org/journal/papers/vol011/pdf/v011a08.pdf
    if p.uri.to_s =~ /\/journal\/papers\/\S+\.php$/i
      pdf_url = p.uri.to_s.gsub(/\/journal\/papers\/(\S+)\.php$/i, '/journal/papers/\1.pdf')
      return pdf_url
    end
  end

  def allen_press(m,p)
    # allenpress.com
    # karger.com
    if p.uri.to_s =~ /karger\.com/i
      pdf_url =  p.links.with.text(/PDF\s+Version/).first.href rescue nil
      return pdf_url
    end
  end

  def landes_bioscience(m,p)
    # landesbioscience.com
    if p.uri.to_s =~ /landesbioscience\.com/i
      id =  p.links.with.text(/Download\s+PDF/).first.href rescue nil
      if id.sub!(/[\.]{0,2}\//, '')
        pdf_url = p.uri.merge(id).to_s
        return pdf_url
      end
    end
  end

  def karger(m,p)
    # karger.com
    if p.uri.to_s =~ /karger\.com/i
      pdf_url =  p.links.with.text(/Article\s+\(PDF/).first.href rescue nil
      return pdf_url
    end
  end

  def jstage(m,p)
    # jstage.jst.go.jp
    if p.uri.to_s =~ /jstage\.jst\.go\.jp/i
      pdf_url =  p.links.with.text(/PDF\s+\(\d+/).first.href rescue nil
      return pdf_url
    end
  end

  def aps(m,p)
    # http://prola.aps.org/abstract/PRL/v61/i9/p1050_1 =>
    # http://prola.aps.org/pdf/PRL/v61/i9/p1050_1
    if p.uri.to_s =~ /aps\.org\/\w+\/\S+$/i
      pdf_url = p.uri.to_s.gsub(/aps\.org\/\w+\/(\S+)$/i, 'aps.org/pdf/\1')
      return pdf_url
    end
  end

  def apa(m,p)
    # http://psycnet.apa.org/index.cfm?fa=search.displayRecord&uid=2000-13978-009 =>
    # http://psycnet.apa.org/index.cfm?fa=main.showContent&id=2000-13978-009&view=fulltext&format=html =>
    # http://psycnet.apa.org/index.cfm?fa=main.showContent&id=2000-13978-009&view=fulltext&format=pdf
    if p.uri.to_s =~ /apa\.org\/index\.cfm\?/i
      id = p.uri.to_s.scan(/apa\.org\/index\.cfm\?\S*id=([\d\-]+)/i).first.first rescue nil
      if id
        pdf_url = p.uri.to_s.gsub(/apa\.org\/index\.cfm\?\S+$/i, "apa.org/index.cfm?fa=main.showContent&id=#{id}&view=fulltext&format=pdf")
        return pdf_url
      end
    end
  end

  def cterm_html(m,p)
    if p.uri.to_s =~ /\/\S+\.(htm|html)$/i
      pdf_url = p.uri.to_s.gsub(/\/(\S+)\.(?:htm|html)$/i, '/\1.pdf')
      return pdf_url
    end
  end

end
