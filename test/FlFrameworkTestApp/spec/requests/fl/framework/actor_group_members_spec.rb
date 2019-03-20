require 'rails_helper'
require 'test_object_helpers'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Framework::Test::ObjectHelpers
end

RSpec.describe Fl::Framework::ListItemsController, type: :request do
  def group_index_url(group, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_group_members_path(group, format: fmt)
  end
  
  def index_url(fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_members_path(format: fmt)
  end
  
  def show_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_member_path(obj, format: fmt)
  end
  
  def group_create_url(group, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_group_members_path(group, format: fmt)
  end
  
  def update_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_member_path(obj, format: fmt)
  end
  
  def delete_url(obj, fmt = :json)
    Fl::Framework::Engine.routes.url_helpers.actor_group_member_path(obj, format: fmt)
  end

  def make_gm_list(ll)
    ll.reduce([ ]) do |acc, l|
      l.members.each { |li| acc << li }
      acc
    end
  end

  def extract_gm(ll)
    ll.map do |li|
      case li
      when Fl::Framework::Actor::GroupMember
        "#{li.group.name} - #{li.actor.name}"
      when Array
        "#{li[0].name} - #{li[1].name}"
      when Hash
        "#{li['group']['name']} - #{li['actor']['name']}"
      else
        ''
      end
    end
  end
  
  let(:a10) { create(:test_actor, name: 'a10') }
  let(:a11) { create(:test_actor, name: 'a11') }
  let(:a12) { create(:test_actor, name: 'a12') }
  let(:a13) { create(:test_actor, name: 'a13') }
  let(:a14) { create(:test_actor, name: 'a14') }
  let(:a15) { create(:test_actor, name: 'a15') }
  let(:a20) { create(:test_actor_two, name: 'a20') }

  let(:g1) { create(:actor_group, actors: [ a10, a12 ],			owner: a10, name: 'g1') }
  let(:g2) { create(:actor_group, actors: [ a10, a14, a15 ],		owner: a10, name: 'g2') }
  let(:g3) { create(:actor_group, actors: [ a13 ],			owner: a12, name: 'g3') }
  let(:g4) { create(:actor_group, actors: [ a12, a14 ], 		owner: a13, name: 'g4') }
  let(:g5) { create(:actor_group, actors: [ a15 ], 			owner: a12, name: 'g5') }
  let(:g6) { create(:actor_group, actors: [ a15, a12, a10, a14 ], 	owner: a10, name: 'g6') }

  describe "GET /fl/framework/actor/group_members" do
    context('with format :json') do
      it "should return a well formed response" do
        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('group_members', '_pg')
        expect(r['group_members']).to be_a(Array)
        expect(r['_pg']).to be_a(Hash)
        expect(r['_pg']).to include('_c', '_s', '_p')
      end

      it 'should return all group members with default options' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]

        get index_url, params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list(xg)
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_groups and :except_groups' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get index_url, params: { _q: { only_groups: [ g1.fingerprint, g4.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g1, g4 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_groups: [ g1.fingerprint, g2.fingerprint, g3.fingerprint,
                                                        g4.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g5, g6 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_groups: [ g2.fingerprint ], only_groups: [ g2.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_groups: [ g2.fingerprint ],
                                       only_groups: [ g2.fingerprint, g3.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g3 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_actors and :except_actors' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get index_url, params: { _q: { only_actors: [ a10.fingerprint, a13.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = extract_gm(r['group_members'])
        xgl = extract_gm([ [ g1, a10 ], [ g2, a10 ], [ g6, a10 ], [ g3, a13 ] ])
        expect(gl).to match_array(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_actors: [ a10.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = extract_gm(r['group_members'])
        xgl = extract_gm([ [ g1, a12 ], [ g2, a14 ], [ g2, a15 ], [ g3, a13 ], [ g4, a12 ],
                           [ g4, a14 ], [ g5, a15 ], [ g6, a15 ], [ g6, a12 ], [ g6, a14 ] ])
        expect(gl).to match_array(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_actors: [ a10.fingerprint ],
                                       only_actors: [ a10.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| "#{gm['group']['name']}-#{gm['actor']['name']}" }
        xgl = [ ]
        expect(gl).to match_array(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { except_actors: [ a12.fingerprint ],
                                       only_actors: [ a12.fingerprint, a14.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = extract_gm(r['group_members'])
        xgl = extract_gm([ [ g2, a14 ], [ g4, a14 ], [ g6, a14 ] ])
        expect(gl).to match_array(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support combinations of :only_ and :except_ options' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get index_url, params: { _q: {
                                   only_groups: [ g1.fingerprint, g4.fingerprint, g5.fingerprint ],
                                   only_actors: [ a10.fingerprint, a12.fingerprint ]
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = extract_gm(r['group_members'])
        xgl = extract_gm([ [ g1, a10 ], [ g1, a12 ], [ g4, a12 ] ])
        expect(gl).to match_array(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: {
                                   only_groups: [ g1.fingerprint, g4.fingerprint, g5.fingerprint ],
                                   except_actors: [ a10.fingerprint, a12.fingerprint ]
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| "#{gm['group']['name']}-#{gm['actor']['name']}" }
        xgl = [
          "#{g4.name}-#{a14.name}",
          "#{g5.name}-#{a15.name}"
        ]
        expect(gl).to match_array(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support order and pagination options' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get index_url, params: { _q: { order: 'title ASC' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| gm['title'] }
        xgl = [ "g1 - a10", "g1 - a12", "g2 - a10", "g2 - a14", "g2 - a15", "g3 - a13",
                "g4 - a12", "g4 - a14", "g5 - a15", "g6 - a10", "g6 - a12", "g6 - a14", "g6 - a15" ]
        expect(gl).to eql(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)

        get index_url, params: { _q: {
                                   only_groups: [ g4.fingerprint ],
                                   order: 'title DESC'
                                 }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| gm['title'] }
        xgl = [ "g4 - a14", "g4 - a12" ]
        expect(gl).to eql(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get index_url, params: { _q: { order: 'title ASC' }, _pg: { _s: 4, _p: 2 } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| gm['title'] }
        xgl = [ "g2 - a15", "g3 - a13", "g4 - a12", "g4 - a14" ]
        expect(gl).to eql(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(3)

        pg = r['_pg']
        get index_url, params: { _q: { order: 'title ASC' }, _pg: pg }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| gm['title'] }
        xgl = [ "g5 - a15", "g6 - a10", "g6 - a12", "g6 - a14" ]
        expect(gl).to eql(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(4)

        pg = r['_pg']
        get index_url, params: { _q: { order: 'title ASC' }, _pg: pg }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gl = r['group_members'].map { |gm| gm['title'] }
        xgl = [ "g6 - a15" ]
        expect(gl).to eql(xgl)
        expect(r['_pg']['_c']).to eql(xgl.count)
        expect(r['_pg']['_p']).to eql(5)
      end

      it "should process to_hash params" do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]

        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        
        d_gm_keys = id_keys | [ "created_at", "updated_at", "group", "actor", "title", "note" ]
        d_group_keys = id_keys | [ "created_at", "updated_at", "name", "note", "owner" ]
        d_actor_keys = id_keys | [ "created_at", "updated_at", "name" ]
        get index_url, params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(d_gm_keys)
        expect(gm0['group'].keys).to match_array(d_group_keys)
        expect(gm0['actor'].keys).to match_array(d_actor_keys)
        
        get index_url, params: { _q: { order: 'id' }, to_hash: { verbosity: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(id_keys)

        get index_url, params: { _q: { order: 'id' },
                                 to_hash: { verbosity: 'id', include: [ 'actor', 'title' ] }
                               }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(id_keys | [ 'actor', 'title' ])
        expect(gm0['actor'].keys).to match_array(d_actor_keys)

        get index_url, params: {
              _q: { order: 'id' },
              to_hash: {
                verbosity: 'id', include: [ 'group', 'actor' ],
                to_hash: {
                  actor: { verbosity: 'id' },
                  group: { verbosity: 'id' }
                }
              }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(id_keys | [ 'group', 'actor' ])
        expect(gm0['group'].keys).to match_array(id_keys)
        expect(gm0['actor'].keys).to match_array(id_keys)
      end
    end
  end

  describe "GET /fl/framework/actor/groups/:group_id/group_members" do
    context('with format :json') do
      it "should return a well formed response" do
        get group_index_url(g4), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('group_members', '_pg')
        expect(r['group_members']).to be_a(Array)
        expect(r['_pg']).to be_a(Hash)
        expect(r['_pg']).to include('_c', '_s', '_p')
      end

      it "should succeed for an unknown group, but return an empty array" do
        get group_index_url(0), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r['group_members'].count).to eql(0)
      end

      it 'should return all group members with default options' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]

        get group_index_url(g4), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g4 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should ignore :only_groups and :except_groups' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get group_index_url(g4), params: { _q: { only_groups: [ g1.fingerprint, g2.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g4 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g4), params: { _q: { except_groups: [ g1.fingerprint, g4.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g4 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g4), params: { _q: { except_lists: [ g2.fingerprint ],
                                                only_lists: [ g2.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = make_gm_list([ g4 ])
        expect(obj_fingerprints(r['group_members'])).to match_array(obj_fingerprints(xgm))
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support :only_actors and :except_actors' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get group_index_url(g6), params: {
              _q: {
                only_actors: [ a10.fingerprint, a12.fingerprint, a13.fingerprint ]
              }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ [ g6, a10 ], [ g6, a12 ] ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g6), params: { _q: { except_actors: [ a10.fingerprint, a13.fingerprint ] } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ [ g6, a15 ], [ g6, a12 ], [ g6, a14 ] ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g6), params: {
              _q: { only_actors: [ a10.fingerprint ], except_actors: [ a10.fingerprint ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g2), params: {
              _q: { only_actors: [ a12.fingerprint, a14.fingerprint ], except_actors: [ a12.fingerprint ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ [ g2, a14 ] ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g2), params: {
              _q: { only_actors: [ a12.fingerprint, a14.fingerprint ], except_actors: [ a14.fingerprint ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
      end

      it 'should support order and pagination options' do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]
        
        get group_index_url(g6), params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ [ g6, a15 ], [ g6, a12 ], [ g6, a10 ], [ g6, a14 ] ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g6), params: { _q: { order: 'title' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ [ g6, a10 ], [ g6, a12 ], [ g6, a14 ], [ g6, a15 ] ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(2)
        
        get group_index_url(g6), params: { _q: { order: 'id ASC' }, _pg: { _s: 2, _p: 2 } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ [ g6, a10 ], [ g6, a14 ] ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(3)

        pg = r['_pg']
        get group_index_url(g6), params: { _q: { order: 'id ASC' }, _pg: pg }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        xgm = extract_gm([ ])
        expect(extract_gm(r['group_members'])).to match_array(xgm)
        expect(r['_pg']['_c']).to eql(xgm.count)
        expect(r['_pg']['_p']).to eql(4)
      end

      it "should process to_hash params" do
        # trigger group creation
        xg = [ g1, g2, g3, g4, g5, g6 ]

        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        
        d_gm_keys = id_keys | [ "created_at", "updated_at", "group", "actor", "title", "note" ]
        d_group_keys = id_keys | [ "created_at", "updated_at", "name", "note", "owner" ]
        d_actor_keys = id_keys | [ "created_at", "updated_at", "name" ]

        get group_index_url(g4), params: { _q: { order: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(d_gm_keys)
        expect(gm0['group'].keys).to match_array(d_group_keys)
        expect(gm0['actor'].keys).to match_array(d_actor_keys)
        
        get group_index_url(g4), params: { _q: { order: 'id' }, to_hash: { verbosity: 'id' } }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(id_keys)

        get group_index_url(g4), params: {
              _q: { order: 'id' },
              to_hash: { verbosity: 'id', include: [ 'actor', 'title' ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(id_keys | [ 'actor', 'title' ])
        expect(gm0['actor'].keys).to match_array(d_actor_keys)

        get group_index_url(g4), params: {
              _q: { order: 'id' },
              to_hash: {
                verbosity: 'id', include: [ 'group', 'actor' ],
                to_hash: {
                  actor: { verbosity: 'id' },
                  group: { verbosity: 'id' }
                }
              }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm0 = r['group_members'][0]
        expect(gm0.keys).to match_array(id_keys | [ 'group', 'actor' ])
        expect(gm0['group'].keys).to match_array(id_keys)
        expect(gm0['actor'].keys).to match_array(id_keys)
      end
    end
  end

  describe "GET /fl/framework/actor/group_member/:id" do
    context('with format :json') do
      it "should return a well formed response" do
        gm = g4.members[0]
        
        get show_url(gm), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('group_member')
        expect(r['group_member']).to be_a(Hash)
      end

      it "should return the requested group member" do
        gm = g4.members[0]
        
        get show_url(gm), params: { }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group_member']
        expect(l['id']).to eql(gm.id)
        expect(l['title']).to eql(gm.title)
      end

      it "should fail for an unknown group member" do
        get show_url(0), params: { }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end

      it "should process to_hash params" do
        gm = g4.members[0]
        
        id_keys = [ "type", "api_root", "url_path", "fingerprint", "id" ]
        get show_url(gm), params: {
              to_hash: { verbosity: 'id' }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm = r['group_member']
        expect(gm.keys).to match_array(id_keys)

        m_keys = id_keys + [ 'title' ]
        gm = g4.members[0]
        get show_url(gm), params: {
              to_hash: { verbosity: 'id', include: [ 'title' ] }
            }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm = r['group_member']
        expect(gm.keys).to match_array(m_keys)
      end
    end
  end

  describe "POST /fl/framework/actor/groups/:group_id/group_member" do
    context('with format :json') do
      it "should return the new group member" do
        # this creates g5
        l = g5
        
        create_params = {
          actor: a14.fingerprint,
          title: 'a14 in g5'
        }

        expect do
          post group_create_url(g5), params: { fl_framework_actor_group_member: create_params }
        end.to change(Fl::Framework::Actor::GroupMember, :count).by(1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm = r['group_member']
        expect(gm['group']['fingerprint']).to eql(g5.fingerprint)
        expect(gm['actor']['fingerprint']).to eql(a14.fingerprint)
        expect(gm['title']).to eql(create_params[:title])
      end

      it "should ingnore the :group parameter" do
        # this creates g5
        l = g5
        
        create_params = {
          group: g2.fingerprint,
          actor: a14.fingerprint,
          title: 'a14 in g5'
        }

        expect do
          post group_create_url(g5), params: { fl_framework_actor_group_member: create_params }
        end.to change(Fl::Framework::Actor::GroupMember, :count).by(1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        gm = r['group_member']
        expect(gm['group']['fingerprint']).to eql(g5.fingerprint)
        expect(gm['actor']['fingerprint']).to eql(a14.fingerprint)
        expect(gm['title']).to eql(create_params[:title])
      end
    end
  end

  describe "PUT/PATCH /fl/framework/actor/group_members/:id" do
    context('with format :json') do
      it "should return the updated group member" do
        gm = g4.members[0]
        
        update_params = {
          title: 'my new title',
          note: 'my new note'
        }
        put update_url(gm), params: { fl_framework_actor_group_member: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group_member']
        expect(l['title']).to eql(update_params[:title])
        expect(l['note']).to eql(update_params[:note])
        
        update_params = {
          title: 'my new title 2',
          note: 'my new note 2'
        }
        patch update_url(gm), params: { fl_framework_actor_group_member: update_params }
        expect(response).to be_successful
        r = JSON.parse(response.body)
        l = r['group_member']
        expect(l['title']).to eql(update_params[:title])
        expect(l['note']).to eql(update_params[:note])
      end

      it "should fail for an unknown group member" do
        update_params = {
          title: 'my new title',
          note: 'my new note'
        }
        put update_url(0), params: { fl_framework_actor_group_member: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
        
        update_params = {
          name: 'my new name 2'
        }
        patch update_url(0), params: { fl_framework_actor_group_member: update_params }
        expect(response).to have_http_status(:not_found)
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r).to include('_error')
        expect(r['_error']).to include('status', 'message', 'details')
      end
    end
  end

  describe "DELETE /fl/framework/actor/group_members/:id" do
    context('with format :json') do
      it "should delete an existing group member" do
        gm = g4.members[0]
        gm_id = gm.id

        expect do
          delete delete_url(gm), params: { }
        end.to change(Fl::Framework::Actor::GroupMember, :count).by(-1)
        expect(response).to be_successful
        r = JSON.parse(response.body)
        expect(r).to be_a(Hash)
        expect(r.keys).to include('_status')
        expect(r['_status'].keys).to include('status', 'message')
        gm = Fl::Framework::Actor::GroupMember.where('(id = ?)', gm_id).first
        expect(gm).to be_nil
        g4.members.reload
        gl = extract_gm(g4.members)
        xgl = extract_gm([ [ g4, a14 ] ])
        expect(gl).to match_array(xgl)
      end

      it "should fail for an unknown group member" do
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
