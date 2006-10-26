## pdfetch
## v0.4
## 2006-10-25
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

require 'ferret'
require 'camping'
require 'mechanize'
require 'uri'
require 'bio'

include Ferret
include Bio

Camping.goes :Pdfetch

class Reprint < WWW::Mechanize::File    
  # empty class to use as Mechanize pluggable parser for pdf files
end


module Pdfetch::Models
  
  class Article
    
    def self.search(query)
      articles = []
      index = self.get_index()
      index.search_each(query, :limit => :all) do |id, score|
        articles << index[id]
      end
      return articles
    end
  
    def self.destroy(id)
      index = self.get_index()
      index.delete(id.to_s)
      index.close
    end

    def self.find_or_create(id)
      index = self.get_index()
      unless article = index[id.to_s]
        # fetch article data from PubMed
        pmarticle = MEDLINE.new(PubMed.query(id))
        raise if id.to_s != pmarticle.pmid
        title = pmarticle.title
        authors = pmarticle.authors.join(" and ")
        journal = pmarticle.journal
        year = pmarticle.year
        source = pmarticle.source
        abstract = pmarticle.abstract
        mesh = pmarticle.mesh.join("\n")
        # extract content here
        index << {
          :id => id.to_s,
          :title => title,
          :authors => authors,
          :journal => journal,
          :year => year,
          :source => source,
          :abstract => abstract,
          :mesh => mesh }
        index.flush
        article = index[id.to_s]
        index.close # to avoid locking!
      end
      return article
    end

    def self.indexed_ids()
      ids = []
      index = get_index()
      index.search_each(Search::MatchAllQuery.new, :limit => :all) do |id, score|
        ids << index[id][:id]
      end
      return ids
    end
    
    def self.refresh_index
      fs_ids = []
      indexed_ids = self.indexed_ids()
      Dir.glob("*.pdf") do |filename|
        if id = /^(\d+)\.pdf$/i.match(filename)
          id = id[1]
          begin
            self.find_or_create(id)
            fs_ids << id
            unless indexed_ids.include? id
              puts "** #{filename} was successfully indexed"
            end
          rescue
            puts "** error indexing #{filename}"
          end
        end
      end
      for id in (self.indexed_ids() - fs_ids)
        self.destroy(id.to_s)
        puts "** #{id} was successfully unindexed"
      end
      puts
    end
    
    
    private
    
    def self.get_index()
      index = Index::Index.new(:default_input_field => nil,
                               :default_field => '*',
                               :id_field => 'id',
                               :key => 'id',
                               :auto_flush => true,
                               :create_if_missing => true,
                               :path => './index')
      fis = index.field_infos
      unless fis[:title]
        fis.add_field(:id,
                      :index => :untokenized,
                      :term_vector => :no)
  
        fis.add_field(:title, :boost => 10.0)
        fis.add_field(:mesh, :boost => 10.0, :term_vector => :no)
        fis.add_field(:abstract, :boost => 10.0)
        fis.add_field(:authors, :term_vector => :no)
  
        fis.add_field(:year,
                      :index => :untokenized,
                      :term_vector => :no)
      
        fis.add_field(:journal,
                      :index => :untokenized,
                      :term_vector => :no)
        
        fis.add_field(:source,
                      :index => :no,
                      :term_vector => :no)
        
        fis.add_field(:content, :store => :no)
      end
      return index
    end
  end
end

module Pdfetch::Controllers

  class Index < R '/'
    def get
      redirect "http://code.google.com/p/pdfetch/"
    end
  end
  
  class Static < R '/(\d+)\.pdf$'         
    def get(id)
      @id = id.to_s
      @headers['Content-Type'] = "application/pdf"
      @headers['X-Sendfile'] = "#{Dir.getwd}/#{id}.pdf"
    end
  end 

  class Fetch < R '/fetch/(\d+)$'    
    def get(id)
      @id = id.to_s
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
            Article.find_or_create(id)
            success = true
          end
        end
        raise unless success
        puts "** fetching of reprint #{id} succeeded"
        render :success
      rescue
        puts "** fetching of reprint #{id} failed"
        render :failure
      end
    end
  end    

  class Search < R '/search'    
    def get
      if input.q
        @articles = Article.search(input.q)
        render :search_results
      else
        render :search_form
      end
    end
  end

end

  
module Pdfetch::Views

  def layout
    html do
      head do
        script "function gotouri(){location.href=\"#{@uri}\";} function gotopdf(){location.href=\"/#{@id}.pdf\";} function goback(){window.history.back()} function waitngoback(){window.setTimeout(goback(),3000);}", :type => 'text/javascript'
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

  def show
    body do
      _article(@article)
    end
  end
  
  def _article(article)
    body :style => "color: #333; font-family: arial, verdana, sans; font-size: medium;" do
      p article[:title], :style => "font-size: 110%; font-weight: bold; margin-top: 2em;"
      p do
        text article[:source] + "&nbsp;"
        a article[:id], :href => "/fetch/#{article[:id]}"
      end
      p article[:authors], :style => "font-style: italic; font-size: 95%;"
      p article[:abstract], :style => "font-size: 90%;"
    end
  end
  
  def search_results
    body do
      for article in @articles
        _article(article)
      end
    end
  end

  def search_form
    body :onload => "document.forms[0][0].focus();" do
      center :style => "margin-top: 2em;" do
        form do
          input :type => 'text', :name => 'q'
          text "&nbsp;"
          input :type => 'submit', :value => 'Search'
        end
      end
    end
  end

end


class Pdfetch::Finders
  # Finders are functions used to find the pdf reprint off a publisher's website.
  # Pass a finder the mechanize agent (m) and the pubmed linkout page (p), and
  # it will return either the pdf reprint or nil.

  def generic(m,p)
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
      page = m.click p.links.with.text(/sciencedirect/i).and.href(/sciencedirect/i)
      page = m.click page.links.with.href(/sdarticle\.pdf$/i)
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

def Pdfetch.create
  unless $index_is_refreshed
    Pdfetch::Models::Article.refresh_index()
    $index_is_refreshed = true
  end
end
