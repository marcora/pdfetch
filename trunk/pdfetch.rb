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

  class MainCss < R '/main.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = %{
/* main.css */
body { margin: 0; padding: 0; font-size: small; }
a { text-decoration: none;}
h1 { font-size: 110%; }
p { font-size: 90%; }
}
    end
  end

end

module Pdfetch::Views

  def layout
    xhtml_strict do
      head do
        title "PDFetch: #{@article.pmid}"
        link :rel => 'stylesheet', :type => 'text/css', :href => '/main.css', :media => 'screen'
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
