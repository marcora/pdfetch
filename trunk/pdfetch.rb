require 'camping'
require 'bio'

Camping.goes :Pdfetch

module Pdfetch::Controllers

  class MainCss < R '/main.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = %{

/* main.css */
body { margin: 0; padding: 10; font-size: small; font-family: arial, sans; }
a { text-decoration: none;}
h1 { font-size: 110%; }
p { font-size: 90%; }

}
    end
  end

  class Index < R '/(.*)'
    def get(uri)
      begin
        # extract the pmid from the uri
        pmid = /list_uids=(\d+)/.match(uri)[1]
        
        # fetch the article from pubmed using pmid
        @article = Bio::MEDLINE.new(Bio::PubMed.query(pmid))
        
        render :index
      rescue
        render :error
      end
    end
  end
  
end

module Pdfetch::Views

  def layout
    xhtml_strict do
      head do
        link :rel => 'stylesheet', :type => 'text/css', :href => '/main.css', :media => 'screen'
      end
      body do
        self << yield
      end
    end
  end

  def index
    h1 @article.title
    p { "#{u @article.journal} #{b @article.year} #{@article.volume}(#{@article.issue}):#{@article.pages}  PMID:&nbsp;#{a @article.pmid, :href => 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=retrieve&db=pubmed&dopt=abstract&list_uids=' + @article.pmid }" }
    p { "#{i @article.authors.join(' and ')}" } unless @article.authors.empty?
    p @article.abstract unless @article.abstract.blank?
  end

  def error
    p "PDFetch cannot fetch article from PubMed or reprint from publisher. Check that the browser url is correct and that the internet connection is working."
  end

end

def Pdfetch.create
end
