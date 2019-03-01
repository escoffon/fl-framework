require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe "Fl::Framework::Lists", type: :request do
  def index_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.lists_path(format: fmt)
  end
  
  def show_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_path(obj, format: fmt)
  end
  
  def create_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.lists_path(format: fmt)
  end
  
  def update_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_path(obj, format: fmt)
  end
  
  def delete_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.list_path(obj, format: fmt)
  end
  
  def add_object_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.add_object_list_path(obj, format: fmt)
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

  let(:l1) { create(:list, objects: [ [ d21, nil, 'd21' ], [ d10, nil, 'd10' ] ], owner: a1) }
  let(:l2) { create(:list, objects: [ d22, d20 ], owner: a1) }
  let(:l3) { create(:list, objects: [ d11 ], owner: a2) }
  let(:l4) { create(:list, objects: [ d20, d21, d22 ], owner: a3) }
  let(:l5) { create(:list, objects: [ d21 ], owner: a2) }
  let(:l6) { create(:list, objects: [ d10, d21, d22 ], owner: a1) }

  describe "GET /fl/framework/lists" do
    context('with format :json') do
      it("should return a well formed response") do
        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('lists', '_pg')
        expect(r['lists']).to be_a(Array)
        expect(r['_pg']).to be_a(Hash)
        expect(r['_pg']).to include('_c', '_s', '_p')
      end

      it 'should return all lists with default options' do
        # this statement triggers the list creation
        xl = [ l1, l2, l3, l4, l5, l6 ].reverse

        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(xl))
        expect(r['_pg']['_c']).to eql(xl.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_owners and :except_owners' do
        # this statement triggers the list creation
        xl = [ l1, l2, l3, l4, l5, l6 ]
        
        get index_url, params: { _q: { only_owners: [ a1.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l6, l2, l1 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)

        
        get index_url, params: { _q: { only_owners: [ a1.fingerprint, a3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l6, l4, l2, l1 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a2.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l6, l4, l2, l1 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a1.fingerprint, a3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l5, l3 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a2.fingerprint ], only_owners: [ a2.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a2.fingerprint ], only_owners: [ a2.fingerprint,
                                                                                         a3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l4 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support order and pagination options' do
        # this statement triggers the list creation
        xl = [ l1, l2, l3, l4, l5, l6 ]
        
        get index_url, params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = xl
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
      
        get index_url, params: { _q: { only_owners: [ a1.fingerprint ], order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l1, l2, l6 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)

        get index_url, params: { _q: { order: 'id' }, _pg: { _s: 2, _p: 2 } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l3, l4 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_s']).to eql(2)
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(3)

        pg = r['_pg']
        get index_url, params: { _q: { order: 'id' }, _pg: pg }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ l5, l6 ]
        expect(obj_fingerprints(r['lists'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_s']).to eql(2)
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(4)
      end

      it("should process to_hash params") do
        # this statement triggers the list creation
        xl = [ l1, l2, l3, l4, l5, l6 ]

        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        
        d_list_keys = id_keys | [ "created_at", "updated_at", "caption", "title", "owner",
                                  "default_readonly_state", "list_display_preferences" ]
        d_owner_keys = id_keys | [ "created_at", "updated_at", "name" ]
        get index_url, params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['lists'][0]
        expect(l0.keys).to match_array(d_list_keys)
        expect(l0['owner'].keys).to match_array(d_owner_keys)
        
        get index_url, params: { _q: { order: 'id' }, to_hash: { verbosity: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['lists'][0]
        expect(l0.keys).to match_array(id_keys)

        get index_url, params: { _q: { order: 'id' },
                                 to_hash: { verbosity: 'id', include: [ 'owner', 'title' ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['lists'][0]
        expect(l0.keys).to match_array(id_keys | [ 'owner', 'title' ])
        expect(l0['owner'].keys).to match_array(d_owner_keys)

        get index_url, params: {
              _q: { order: 'id' },
              to_hash: {
                verbosity: 'id', include: [ 'owner', 'title' ],
                to_hash: {
                  owner: { verbosity: 'id' }
                }
              }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['lists'][0]
        expect(l0.keys).to match_array(id_keys | [ 'owner', 'title' ])
        expect(l0['owner'].keys).to match_array(id_keys)
      end
    end
  end

  describe "GET /fl/framework/lists/:id" do
    context('with format :json') do
      it("should return a well formed response") do
        get show_url(l1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('list')
        expect(r['list']).to be_a(Hash)
      end

      it("should return the requested list") do
        get show_url(l1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list']
        expect(l['id']).to eql(l1.id)
        expect(l['title']).to eql(l1.title)
        expect(l['caption']).to eql(l1.caption)
      end

      it("should fail for an unknown list") do
        get show_url(0), params: { }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should process to_hash params") do
        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        get show_url(l2), params: {
              to_hash: { verbosity: 'id' }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list']
        expect(l.keys).to match_array(id_keys)

        m_keys = id_keys + [ 'title' ]
        get show_url(l2), params: {
              to_hash: { verbosity: 'id', include: [ 'title' ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list']
        expect(l.keys).to match_array(m_keys)
      end
    end
  end

  describe "POST /fl/framework/lists" do
    context('with format :json') do
      it("should return the new list") do
        create_params = {
          owner: a2.fingerprint,
          title: 'my title',
          caption: 'my caption'
        }

        expect do
          post create_url(), params: { fl_framework_list: create_params }
        end.to change(Fl::Framework::List::List, :count).by(1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list']
        expect(l['title']).to eql(create_params[:title])
        expect(l['caption']).to eql(create_params[:caption])
      end
    end
  end

  describe "PUT/PATCH /fl/framework/lists/:id" do
    context('with format :json') do
      it("should return the updated list") do
        update_params = {
          title: 'my new title',
          caption: 'my new caption'
        }
        put update_url(l1), params: { fl_framework_list: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list']
        expect(l['title']).to eql(update_params[:title])
        expect(l['caption']).to eql(update_params[:caption])

        update_params = {
          title: 'my new title 2',
          caption: 'my new caption 2'
        }
        patch update_url(l2), params: { fl_framework_list: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['list']
        expect(l['title']).to eql(update_params[:title])
        expect(l['caption']).to eql(update_params[:caption])
      end

      it("should fail for an unknown list") do
        update_params = {
          title: 'my new title',
          caption: 'my new caption'
        }

        put update_url(0), params: { fl_framework_list: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')

        patch update_url(0), params: { fl_framework_list: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end

  describe "DELETE /fl/framework/lists/:id" do
    context('with format :json') do
      it("should delete an existing list") do
        l1_id = l1.id

        delete delete_url(l1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r.keys).to include('_status')
        expect(r['_status'].keys).to include('status', 'message')
        l = Fl::Framework::List::List.where('(id = ?)', l1_id).first
        expect(l).to be_nil
      end

      it("should fail for an unknown list") do
        delete delete_url(0), params: { }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end

  describe "POST /fl/framework/lists/:id/add_object" do
    context('with format :json') do
      it("should return the new list item") do
        add_params = {
          listed_object: d22.fingerprint,
          name: 'd22'
        }
        no = l1.next_sort_order

        post add_object_url(l1), params: { fl_framework_list: add_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r.keys).to include('list_item')
        li = r['list_item']
        expect(li).to be_a(Hash)
        expect(li.keys).to include('type', 'list', 'listed_object', 'owner', 'name')
        expect(li['type']).to eql(Fl::Framework::List::ListItem.name)
        expect(li['list']['fingerprint']).to eql(l1.fingerprint)
        expect(li['listed_object']['fingerprint']).to eql(d22.fingerprint)
        expect(li['name']).to eql('d22')
        expect(li['sort_order']).to eql(no)
      end

      it("should fail for an unknown list") do
        add_params = {
          listed_object: d22.fingerprint,
          name: 'd22'
        }

        post add_object_url(0), params: { fl_framework_list: add_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should return an existing list item if already in the list") do
        add_params = {
          listed_object: d21.fingerprint,
          name: 'd21-new'
        }
        no = l1.next_sort_order

        post add_object_url(l1), params: { fl_framework_list: add_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r.keys).to include('list_item')
        li = r['list_item']
        expect(li).to be_a(Hash)
        expect(li.keys).to include('type', 'list', 'listed_object', 'owner', 'name')
        expect(li['type']).to eql(Fl::Framework::List::ListItem.name)
        expect(li['list']['fingerprint']).to eql(l1.fingerprint)
        expect(li['listed_object']['fingerprint']).to eql(d21.fingerprint)
        expect(li['name']).to eql('d21')
      end

      it("should fail for a missing listed object") do
        add_params = {
        }

        post add_object_url(l1), params: { fl_framework_list: add_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        print("++++++++++ #{r}\n")
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should fail for an unknown listed object") do
        add_params = {
          listed_object: 'TestDatumOne/0',
          name: 'd30'
        }

        post add_object_url(l1), params: { fl_framework_list: add_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        print("++++++++++ #{r}\n")
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should fail if the listed object is not listable") do
        add_params = {
          listed_object: d30.fingerprint,
          name: 'd30'
        }

        post add_object_url(0), params: { fl_framework_list: add_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end
end
