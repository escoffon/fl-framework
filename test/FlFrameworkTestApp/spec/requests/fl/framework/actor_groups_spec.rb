require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe "Fl::Framework::Actor::Group", type: :request do
  def index_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_groups_path(format: fmt)
  end
  
  def show_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_path(obj, format: fmt)
  end
  
  def create_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_groups_path(format: fmt)
  end
  
  def update_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_path(obj, format: fmt)
  end
  
  def delete_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_path(obj, format: fmt)
  end
  
  def add_actor_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.add_actor_actor_group_path(obj, format: fmt)
  end
  
  let(:a10) { create(:test_actor, name: 'a10') }
  let(:a11) { create(:test_actor, name: 'a11') }
  let(:a12) { create(:test_actor, name: 'a12') }
  let(:a13) { create(:test_actor, name: 'a13') }
  let(:a14) { create(:test_actor, name: 'a14') }
  let(:a15) { create(:test_actor, name: 'a15') }
  let(:a20) { create(:test_actor_two, name: 'a20') }

  let(:g1) { create(:actor_group, actors: [ a10, a12 ],		owner: a10, name: 'g1') }
  let(:g2) { create(:actor_group, actors: [ a10, a14, a15 ],	owner: a10, name: 'g2') }
  let(:g3) { create(:actor_group, actors: [ a13 ],		owner: a12, name: 'g3') }
  let(:g4) { create(:actor_group, actors: [ a12, a14 ], 	owner: a13, name: 'g4') }
  let(:g5) { create(:actor_group, actors: [ a15 ], 		owner: a12, name: 'g5') }
  let(:g6) { create(:actor_group, actors: [ a15, a12, a10 ], 	owner: a10, name: 'g6') }

  describe "GET /fl/framework/actor/groups" do
    context('with format :json') do
      it("should return a well formed response") do
        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('groups', '_pg')
        expect(r['groups']).to be_a(Array)
        expect(r['_pg']).to be_a(Hash)
        expect(r['_pg']).to include('_c', '_s', '_p')
      end

      it 'should return all groups with default options' do
        # this statement triggers the group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]

        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(obj_fingerprints(r['groups'])).to match_array(obj_fingerprints(xg))
        expect(r['_pg']['_c']).to eql(xg.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_owners and :except_owners' do
        # this statement triggers the group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get index_url, params: { _q: { only_owners: [ a10.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g6, g2, g1 ]
        expect(obj_fingerprints(r['groups'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { only_owners: [ a10.fingerprint, a13.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g6, g4, g2, g1 ]
        expect(obj_fingerprints(r['groups'])).to match_array(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a12.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g6, g4, g2, g1 ]
        expect(obj_fingerprints(r['groups'])).to match_array(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a10.fingerprint, a13.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g5, g3 ]
        expect(obj_fingerprints(r['groups'])).to match_array(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a12.fingerprint ],
                                       only_owners: [ a12.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ ]
        expect(obj_fingerprints(r['groups'])).to match_array(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_owners: [ a12.fingerprint ],
                                       only_owners: [ a12.fingerprint, a13.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g4 ]
        expect(obj_fingerprints(r['groups'])).to match_array(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support order and pagination options' do
        # this statement triggers the group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get index_url, params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = xg
        expect(obj_fingerprints(r['groups'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)
      
        get index_url, params: { _q: { only_owners: [ a10.fingerprint ], order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g1, g2, g6 ]
        expect(obj_fingerprints(r['groups'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(2)

        get index_url, params: { _q: { order: 'id' }, _pg: { _s: 2, _p: 2 } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g3, g4 ]
        expect(obj_fingerprints(r['groups'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_s']).to eql(2)
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(3)

        pg = r['_pg']
        get index_url, params: { _q: { order: 'id' }, _pg: pg }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        x = [ g5, g6 ]
        expect(obj_fingerprints(r['groups'])).to eql(obj_fingerprints(x))
        expect(r['_pg']['_s']).to eql(2)
        expect(r['_pg']['_c']).to eql(x.count)
        expect(r['_pg']['_p']).to eql(4)
      end

      it("should process to_hash params") do
        # this statement triggers the group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]

        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        
        d_group_keys = id_keys | [ 'name', 'note', 'owner', 'created_at', 'updated_at' ]
        d_owner_keys = id_keys | [ "created_at", "updated_at", "name" ]
        get index_url, params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['groups'][0]
        expect(l0.keys).to match_array(d_group_keys)
        expect(l0['owner'].keys).to match_array(d_owner_keys)
        
        get index_url, params: { _q: { order: 'id' }, to_hash: { verbosity: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['groups'][0]
        expect(l0.keys).to match_array(id_keys)

        get index_url, params: { _q: { order: 'id' },
                                 to_hash: { verbosity: 'id', include: [ 'owner', 'name' ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['groups'][0]
        expect(l0.keys).to match_array(id_keys | [ 'owner', 'name' ])
        expect(l0['owner'].keys).to match_array(d_owner_keys)

        get index_url, params: {
              _q: { order: 'id' },
              to_hash: {
                verbosity: 'id', include: [ 'owner', 'name', 'members' ],
                to_hash: {
                  owner: { verbosity: 'id' },
                  members: { verbosity: 'id', include: [ 'actor' ] }
                }
              }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l0 = r['groups'][0]
        expect(l0.keys).to match_array(id_keys | [ 'owner', 'name', 'members' ])
        expect(l0['owner'].keys).to match_array(id_keys)
        expect(l0['members'][0].keys).to match_array(id_keys | [ 'actor' ])
      end
    end
  end

  describe "GET /fl/framework/actor/groups/:id" do
    context('with format :json') do
      it("should return a well formed response") do
        get show_url(g1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('group')
        expect(r['group']).to be_a(Hash)
      end

      it("should return the requested group") do
        get show_url(g1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l['fingerprint']).to eql(g1.fingerprint)
        expect(l['name']).to eql(g1.name)
        expect(l['note']).to eql(g1.note)
      end

      it("should fail for an unknown group") do
        get show_url(0), params: { }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should return group members on request") do
        get show_url(g1), params: { with_members: 1 }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l['fingerprint']).to eql(g1.fingerprint)
        expect(l.keys).to include('members')
        expect(l['members']).to be_a(Array)

        # The group members should have gone through to_hash; we check this by confirming that there
        # are :type, :fingerprint, :group, and :actor keys

        gm = l['members'][0]
        expect(gm.keys).to include('type', 'fingerprint', 'group', 'actor')
      end

      it("should process to_hash params") do
        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        get show_url(g2), params: {
              to_hash: { verbosity: 'id' }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l.keys).to match_array(id_keys)

        m_keys = id_keys + [ 'name' ]
        get show_url(g2), params: {
              to_hash: { verbosity: 'id', include: [ 'name' ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l.keys).to match_array(m_keys)
      end
    end
  end

  describe "POST /fl/framework/actor/groups" do
    context('with format :json') do
      it("should return the new group") do
        create_params = {
          owner: a12.fingerprint,
          name: 'gname',
          note: 'the note'
        }

        expect do
          post create_url(), params: { fl_framework_actor_group: create_params }
        end.to change(Fl::Framework::Actor::Group, :count).by(1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l['name']).to eql(create_params[:name])
        expect(l['note']).to eql(create_params[:note])
      end

      it("should accept the :actors parameter") do
        create_params = {
          owner: a12.fingerprint,
          name: 'gname',
          note: 'the note',
          actors: [ a10.fingerprint, a14.fingerprint ]
        }

        expect do
          post create_url(), params: { fl_framework_actor_group: create_params }
        end.to change(Fl::Framework::Actor::Group, :count).by(1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l['name']).to eql(create_params[:name])
        expect(l['note']).to eql(create_params[:note])

        g = Fl::Framework::Actor::Group.where('(name = ?)', l['name']).first
        expect(g).to be_a(Fl::Framework::Actor::Group)
        expect(obj_fingerprints(g.actors)).to match_array(create_params[:actors])
      end

      it("should fail on a duplicate group name") do
        create_params = {
          owner: a12.fingerprint,
          name: g4.name,
          note: 'the note'
        }

        expect do
          post create_url(), params: { fl_framework_actor_group: create_params }
        end.not_to change(Fl::Framework::Actor::Group, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end

  describe "PUT/PATCH /fl/framework/actor/groups/:id" do
    context('with format :json') do
      it("should return the updated group") do
        update_params = {
          name: 'my new name',
          note: 'my new note'
        }
        put update_url(g1), params: { fl_framework_actor_group: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l['fingerprint']).to eql(g1.fingerprint)
        expect(l['name']).to eql(update_params[:name])
        expect(l['note']).to eql(update_params[:note])

        update_params = {
          name: 'my new name 1',
          note: 'my new note 1'
        }
        patch update_url(g1), params: { fl_framework_actor_group: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group']
        expect(l['fingerprint']).to eql(g1.fingerprint)
        expect(l['name']).to eql(update_params[:name])
        expect(l['note']).to eql(update_params[:note])
      end

      it("should fail for an unknown group") do
        update_params = {
          title: 'my new title',
          caption: 'my new caption'
        }

        put update_url(0), params: { fl_framework_actor_group: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')

        patch update_url(0), params: { fl_framework_actor_group: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end

  describe "DELETE /fl/framework/actor/groups/:id" do
    context('with format :json') do
      it("should delete an existing group") do
        g1_id = g1.id
        
        delete delete_url(g1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r.keys).to include('_status')
        expect(r['_status'].keys).to include('status', 'message')
        l = Fl::Framework::Actor::Group.where('(id = ?)', g1_id).first
        expect(l).to be_nil
      end

      it("should delete group members") do
        g1_id = g1.id
        gm1 = Fl::Framework::Actor::GroupMember.where('(group_id = ?)', g1_id).to_a
        expect(gm1.count).to eql(2)
        
        delete delete_url(g1), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r.keys).to include('_status')
        expect(r['_status'].keys).to include('status', 'message')

        gm2 = Fl::Framework::Actor::GroupMember.where('(group_id = ?)', g1_id).to_a
        expect(gm2.count).to eql(0)
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

  describe "POST /fl/framework/actor/groups/:id/add_actor" do
    context('with format :json') do
      it("should return the new group member") do
        add_params = {
          actor: a14.fingerprint,
          title: 'a14',
          note: 'a14 note'
        }

        post add_actor_url(g1), params: { fl_framework_actor_group: add_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r.keys).to include('group_member')
        gm = r['group_member']
        expect(gm).to be_a(Hash)
        expect(gm.keys).to include('actor', 'group', 'title', 'note')
        expect(gm['type']).to eql(Fl::Framework::Actor::GroupMember.name)
        expect(gm['group']['fingerprint']).to eql(g1.fingerprint)
        expect(gm['actor']['fingerprint']).to eql(a14.fingerprint)
        expect(gm['title']).to eql(add_params[:title])
        expect(gm['note']).to eql(add_params[:note])
      end

      it("should fail for an unknown group") do
        add_params = {
          actor: a14.fingerprint,
          title: 'a14',
          note: 'a14 note'
        }

        post add_actor_url(0), params: { fl_framework_actor_group: add_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should return an existing list item if already in the list") do
        add_params = {
          actor: a10.fingerprint,
          title: 'a10 - new',
          note: 'a10 note - new'
        }

        gm1 = g1.find_group_member(a10)
        expect(gm1).not_to be_nil
        
        post add_actor_url(g1), params: { fl_framework_actor_group: add_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r.keys).to include('group_member')
        gm = r['group_member']
        expect(gm).to be_a(Hash)
        expect(gm['type']).to eql(Fl::Framework::Actor::GroupMember.name)
        expect(gm['id']).to eql(gm1.id)
        expect(gm['group']['fingerprint']).to eql(gm1.group.fingerprint)
        expect(gm['actor']['fingerprint']).to eql(a10.fingerprint)
        expect(gm['actor']['fingerprint']).to eql(gm1.actor.fingerprint)
        expect(gm['title']).to eql(gm1.title)
        expect(gm['note']).to eql(gm1.note)
      end

      it("should fail for a missing actor") do
        add_params = {
        }

        post add_actor_url(g1), params: { fl_framework_actor_group: add_params }
        expect(response).to have_http_status(:unprocessable_entity)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should fail for an unknown actor") do
        add_params = {
          actor: 'TestActor/0',
          title: 'a0'
        }

        post add_actor_url(g1), params: { fl_framework_actor_group: add_params }
        expect(response).to have_http_status(:unprocessable_entity)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it("should fail if the actor is not an actor") do
        add_params = {
          actor: a20.fingerprint
        }

        post add_actor_url(g1), params: { fl_framework_actor_group: add_params }
        expect(response).to have_http_status(:unprocessable_entity)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end
end
