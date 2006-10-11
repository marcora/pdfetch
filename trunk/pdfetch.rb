require 'camping'

require 'htmlentities'
require 'bio'
include Bio

Camping.goes :Pdfetch

module Pdfetch::Controllers

  class Index < R '/(\d+)'
    def get(pmid)
      @article = MEDLINE.new(PubMed.query(pmid))
      if pmid.to_s != @article.pmid
        render :error
      else
        render :index
      end
    end
  end

end

module Pdfetch::Views

  def layout
    xhtml_strict do
      head do
        title "PDFetch: #{@article.pmid}"
      end
      body do
        self << yield
      end
    end
  end

  def index
    h1 @article.title
    p { "#{u @article.journal} #{b @article.year} #{@article.volume}(#{@article.issue}):#{@article.pages}  PMID:&nbsp;#{a @article.pmid, :href => 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=search&db=pubmed&term=' + @article.pmid }" }
    p { "#{i @article.authors.join(' and ')}" } unless @article.authors.empty?
    p @article.abstract unless @article.abstract.blank?
  end

  def error
    p "PDFetch cannot fetch article from PubMed or reprint from publisher."
  end

end

def Pdfetch.create
end
