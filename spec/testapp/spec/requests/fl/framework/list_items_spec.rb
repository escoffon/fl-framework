require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe "Fl::Framework::ListItems", type: :request do
  def index_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_items_path(format: fmt)
  end
  
  def show_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_item_path(obj, format: fmt)
  end
  
  def create_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_items_path(format: fmt)
  end
  
  def update_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_item_path(obj, format: fmt)
  end
  
  def delete_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_item_path(obj, format: fmt)
  end

  def make_li_list(ll)
    ll.reduce([ ]) do |acc, l|
      l.list_items.each { |li| acc << li }
      acc
    end
  end

  def extract_li(ll)
    ll.map do |li|
      case li
      when Fl::Framework::List::ListItem
        "#{li.list.fingerprint}-#{li.listed_object.fingerprint}"
      when Array
        "#{li[0].fingerprint}-#{li[1].fingerprint}"
      when Hash
        "#{li['list']['fingerprint']}-#{li['listed_object']['fingerprint']}"
      else
        ''
      end
    end
  end
  
  let(:a1) { create(:test_actor) }
  let(:a2) { create(:test_actor) }
  let(:a3) { create(:test_actor) }
  let(:d10) { create(:test_datum_one, owner: a1, value: 10) }
  let(:d11) { create(:test_datum_one, owner: a2, value: 11) }
  let(:d20) { create(:test_datum_two, owner: a2, value: 'v20') }
  let(:d21) { create(:test_datum_two, owner: a1, value: 'v21') }
  let(:d22) { create(:test_datum_two, owner: a1, value: 'v22') }
  let(:d30) { create(:test_datum_three, owner: a1, value: 30) }

  let(:l1) { create(:list, objects: [ [ d21, a1, 'd21' ], [ d10, a2, 'd10' ] ], owner: a1) }
  let(:l2) { create(:list, objects: [ [ d22, a2, 'd22' ], [ d20, a3, 'd20' ] ], owner: a1) }
  let(:l3) { create(:list, objects: [ [ d11, a1, 'd11' ] ], owner: a2) }
  let(:l4) { create(:list, objects: [ [ d20, a2, 'd20' ], [ d21, a1, 'd21' ], [ d22, a3, 'd22' ] ], owner: a3) }
  let(:l5) { create(:list, objects: [ [ d21, a2, 'd21' ] ], owner: a2) }
  let(:l6) { create(:list, objects: [ [ d10, a1, 'd10' ], [ d21, a1, 'd21' ], [ d22, a3, 'd22' ] ], owner: a1) }

  describe "GET /fl/framework/list_items" do
    context('with format :json') do
      it "should return a well formed response" do
        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('list_items', '_pg')
        expect(r['list_items']).to be_a(Array)
        expect(r['_pg']).to be_a(Hash)
        expect(r['_pg']).to include('_c', '_s', '_p')
      end

      it 'should return all list items with default options' do
        # this statement triggers the list creation
        xli = make_li_list([ l1, l2, l3, l4, l5, l6 ])

        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(obj_fingerprints(r['list_items']).sort).to eql(obj_fingerprints(xli).sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_lists and :except_lists' do
        # this statement triggers the list creation
        xl = [ l1, l2, l3, l4, l5, l6 ]
        
        get index_url, params: { _q: { only_lists: [ l1.fingerprint, l4.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = make_li_list([ l1, l4 ])
        expect(obj_fingerprints(r['list_items']).sort).to eql(obj_fingerprints(xli.sort))
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_lists: [ l1.fingerprint, l2.fingerprint, l3.fingerprint,
                                                       l4.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = make_li_list([ l5, l6 ])
        expect(obj_fingerprints(r['list_items']).sort).to eql(obj_fingerprints(xli.sort))
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_lists: [ l2.fingerprint ], only_lists: [ l2.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = make_li_list([ ])
        expect(obj_fingerprints(r['list_items']).sort).to eql(obj_fingerprints(xli.sort))
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_lists: [ l2.fingerprint ],
                                       only_lists: [ l2.fingerprint, l3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = make_li_list([ l3 ])
        expect(obj_fingerprints(r['list_items']).sort).to eql(obj_fingerprints(xli.sort))
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_owners and :except_owners' do
        # this statement triggers the list creation
        xl = [ l1, l2 ]
        
        get index_url, params: { _q: { only_owners: [ a1.fingerprint, a3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l1, d21 ], [ l2, d20 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a1.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l1, d10 ], [ l2, d22 ], [ l2, d20 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a1.fingerprint ], only_owners: [ a1.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a2.fingerprint ],
                                       only_owners: [ a2.fingerprint, a3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l2, d20 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_listables and :except_listables' do
        # this statement triggers the list creation
        xl = [ l2, l3, l4, l5 ]
        
        get index_url, params: { _q: { only_listables: [ d21.fingerprint, d10.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l4, d21 ], [ l5, d21 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_listables: [ d22.fingerprint, d21.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l2, d20 ], [ l3, d11 ], [ l4, d20 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_listables: [ d21.fingerprint ], only_listables: [ d21.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_listables: [ d21.fingerprint ],
                                       only_listables: [ d21.fingerprint, d22.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l2, d22 ], [ l4, d22 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support combinations of :only_ and :except_ options' do
        # this statement triggers the list creation
        xl = [ l1, l2, l3, l4, l5, l6 ]
        
        get index_url, params: { _q: {
                                   only_lists: [ l1.fingerprint, l4.fingerprint, l5.fingerprint ],
                                   only_listables: [ d21.fingerprint, d10.fingerprint ]
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l1, d10 ], [ l1, d21 ], [ l4, d21 ], [ l5, d21 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: {
                                   only_lists: [ l1.fingerprint, l4.fingerprint, l5.fingerprint ],
                                   only_listables: [ d21.fingerprint, d10.fingerprint ],
                                   only_owners: [ a1.fingerprint ]
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l1, d21 ], [ l4, d21 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: {
                                   only_lists: [ l1.fingerprint, l4.fingerprint, l5.fingerprint ],
                                   only_listables: [ d21.fingerprint, d10.fingerprint ],
                                   except_owners: [ a1.fingerprint ]
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l1, d10 ], [ l5, d21 ] ])
        expect(extract_li(r['list_items']).sort).to eql(xli.sort)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support order and pagination options' do
        # this statement triggers the list creation
        xl = [ l3, l4, l5 ]
        
        get index_url, params: { _q: { order: 'list_id ASC, id ASC' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l3, d11 ], [ l4, d20 ], [ l4, d21 ], [ l4, d22 ], [ l5, d21 ] ])
        expect(extract_li(r['list_items'])).to eql(xli)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)

        get index_url, params: { _q: {
                                   only_lists: [ l4.fingerprint ],
                                   order: 'list_id ASC, id ASC'
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l4, d20 ], [ l4, d21 ], [ l4, d22 ] ])
        expect(extract_li(r['list_items'])).to eql(xli)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { order: 'list_id ASC, id ASC' }, _pg: { _s: 2, _p: 2 } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l4, d21 ], [ l4, d22 ] ])
        expect(extract_li(r['list_items'])).to eql(xli)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(3)

        pg = r['_pg']
        get index_url, params: { _q: { order: 'id' }, _pg: pg }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xli = extract_li([ [ l5, d21 ] ])
        expect(extract_li(r['list_items'])).to eql(xli)
        expect(r['_pg']['_c']).to eql(xli.count)
        expect(r['_pg']['_p']).to eql(4)
      end

      it "should process to_hash params" do
        # this statement triggers the list creation
        xl = [ l1 ]

        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        
        d_li_keys = id_keys | [ "created_at", "updated_at", "list", "listed_object", "owner",
                                "readonly_state", "state", "state_updated_at", "state_updated_by", "state_note",
                                "sort_order", "item_summary", "name" ]
        d_list_keys = id_keys | [ "created_at", "updated_at",
                                  "caption", "title", "owner",
                                  "default_readonly_state", "list_display_preferences" ]
        d_owner_keys = id_keys | [ "created_at", "updated_at", "name" ]
        get index_url, params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li0 = r['list_items'][0]
        expect(li0.keys).to match_array(d_li_keys)
        expect(li0['list'].keys).to match_array(d_list_keys)
        expect(li0['owner'].keys).to match_array(d_owner_keys)
        
        get index_url, params: { _q: { order: 'id' }, to_hash: { verbosity: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li0 = r['list_items'][0]
        expect(li0.keys).to match_array(id_keys)

        get index_url, params: { _q: { order: 'id' },
                                 to_hash: { verbosity: 'id', include: [ 'owner', 'name' ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li0 = r['list_items'][0]
        expect(li0.keys).to match_array(id_keys | [ 'owner', 'name' ])
        expect(li0['owner'].keys).to match_array(d_owner_keys)

        get index_url, params: {
              _q: { order: 'id' },
              to_hash: {
                verbosity: 'id', include: [ 'list', 'listed_object', 'owner' ],
                to_hash: {
                  owner: { verbosity: 'id' },
                  list: { verbosity: 'id' },
                  listed_object: { verbosity: 'id' }
                }
              }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li0 = r['list_items'][0]
        expect(li0.keys).to match_array(id_keys | [ 'list', 'listed_object', 'owner' ])
        expect(li0['list'].keys).to match_array(id_keys)
        expect(li0['owner'].keys).to match_array(id_keys)
        expect(li0['listed_object'].keys).to match_array(id_keys)
      end
    end
  end

  describe "GET /fl/framework/list_items/:id" do
    context('with format :json') do
      it "should return a well formed response" do
        li = l1.list_items[0]
        
        get show_url(li), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('list_item')
        expect(r['list_item']).to be_a(Hash)
      end

      it "should return the requested list item" do
        li = l1.list_items[0]
        
        get show_url(li), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list_item']
        expect(l['id']).to eql(li.id)
        expect(l['name']).to eql(li.name)
      end

      it "should fail for an unknown list item" do
        get show_url(0), params: { }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it "should process to_hash params" do
        li = l1.list_items[0]
        
        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        get show_url(li), params: {
              to_hash: { verbosity: 'id' }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li = r['list_item']
        expect(li.keys).to match_array(id_keys)

        m_keys = id_keys + [ 'name' ]
        li = l1.list_items[0]
        get show_url(li), params: {
              to_hash: { verbosity: 'id', include: [ 'name' ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li = r['list_item']
        expect(li.keys).to match_array(m_keys)
      end
    end
  end

  describe "POST /fl/framework/list_items" do
    context('with format :json') do
      it "should return the new list item" do
        create_params = {
          list: l5.fingerprint,
          listed_object: d10.fingerprint,
          owner: a2.fingerprint,
          name: 'd10'
        }

        expect do
          post create_url(), params: { fl_framework_list_item: create_params }
        end.to change(Fl::Framework::List::ListItem, :count).by(1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        li = r['list_item']
        expect(li['list']['fingerprint']).to eql(l5.fingerprint)
        expect(li['listed_object']['fingerprint']).to eql(d10.fingerprint)
        expect(li['owner']['fingerprint']).to eql(a2.fingerprint)
        expect(li['name']).to eql(create_params[:name])
      end
    end
  end

  describe "PUT/PATCH /fl/framework/list_items/:id" do
    context('with format :json') do
      it "should return the updated list item" do
        li = l1.list_items[0]
        
        update_params = {
          name: 'my new name'
        }
        put update_url(li), params: { fl_framework_list_item: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list_item']
        expect(l['name']).to eql(update_params[:name])
        
        update_params = {
          name: 'my new name 2'
        }
        patch update_url(li), params: { fl_framework_list_item: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list_item']
        expect(l['name']).to eql(update_params[:name])
      end

      it "should fail for an unknown list item" do
        update_params = {
          name: 'my new name'
        }

        put update_url(0), params: { fl_framework_list_item: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')

        patch update_url(0), params: { fl_framework_list_item: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end

  describe "DELETE /fl/framework/list_items/:id" do
    context('with format :json') do
      it "should delete an existing list item" do
        li = l1.list_items[0]
        li_id = li.id

        delete delete_url(li), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r.keys).to include('_status')
        expect(r['_status'].keys).to include('status', 'message')
        li = Fl::Framework::List::ListItem.where('(id = ?)', li_id).first
        expect(li).to be_nil
        l1.list_items.reload
        xo = l1.list_items.map { |li| li.listed_object }
        expect(obj_fingerprints(xo)).to eql(obj_fingerprints([ d10 ]))
      end

      it "should fail for an unknown list item" do
        delete delete_url(0), params: { }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end
end
