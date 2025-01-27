##########################################
### (1) General methods
##########################################

@doc raw"""
    blow_up(m::AbstractFTheoryModel, ideal_gens::Vector{String}; coordinate_name::String = "e")

Resolve an F-theory model by blowing up a locus in the ambient space.

# Examples
```jldoctest
julia> B3 = projective_space(NormalToricVariety, 3)
Normal toric variety

julia> w = torusinvariant_prime_divisors(B3)[1]
Torus-invariant, prime divisor on a normal toric variety

julia> t = literature_model(arxiv_id = "1109.3454", equation = "3.1", base_space = B3, model_sections = Dict("w" => w), completeness_check = false)
Construction over concrete base may lead to singularity enhancement. Consider computing singular_loci. However, this may take time!

Global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> blow_up(t, ["x", "y", "x1"]; coordinate_name = "e1")
Partially resolved global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)
```
Here is an example for a Weierstrass model.

# Examples
```jldoctest
julia> B2 = projective_space(NormalToricVariety, 2)
Normal toric variety

julia> b = torusinvariant_prime_divisors(B2)[1]
Torus-invariant, prime divisor on a normal toric variety

julia> w = literature_model(arxiv_id = "1208.2695", equation = "B.19", base_space = B2, model_sections = Dict("b" => b), completeness_check = false)
Construction over concrete base may lead to singularity enhancement. Consider computing singular_loci. However, this may take time!

Weierstrass model over a concrete base -- U(1) Weierstrass model based on arXiv paper 1208.2695 Eq. (B.19)

julia> blow_up(w, ["x", "y", "x1"]; coordinate_name = "e1")
Partially resolved Weierstrass model over a concrete base -- U(1) Weierstrass model based on arXiv paper 1208.2695 Eq. (B.19)
```
"""
function blow_up(m::AbstractFTheoryModel, ideal_gens::Vector{String}; coordinate_name::String = "e")
  R = cox_ring(ambient_space(m))
  I = ideal([eval_poly(k, R) for k in ideal_gens])
  return blow_up(m, I; coordinate_name = coordinate_name)
end

function _my_proper_transform(ring_map::T, p::MPolyRingElem, coordinate_name::String) where {T<:SetElem}
  total_transform = ring_map(ideal([p]))
  _e = eval_poly(coordinate_name, codomain(ring_map))
  exceptional_ideal = total_transform + ideal([_e])
  strict_transform, exceptional_factor = saturation_with_index(total_transform, exceptional_ideal)
  return gens(strict_transform)[1]
end

function blow_up(m::AbstractFTheoryModel, I::MPolyIdeal; coordinate_name::String = "e")
  
  # Cannot (yet) blowup if this is not a Tate or Weierstrass model
  entry_test = (m isa GlobalTateModel) || (m isa WeierstrassModel)
  @req entry_test "Blowups are currently only supported for Tate and Weierstrass models"

  # This method only works if the model is defined over a toric variety over toric scheme
  @req base_space(m) isa NormalToricVariety "Blowups of Tate models are currently only supported for toric bases"
  @req ambient_space(m) isa NormalToricVariety "Blowups of Tate models are currently only supported for toric ambient spaces"

  # Compute the new ambient_space
  bd = blow_up(ambient_space(m), I; coordinate_name = coordinate_name)
  new_ambient_space = domain(bd)

  # Compute the new base
  # FIXME: THIS WILL IN GENERAL BE WRONG! IN PRINCIPLE, THE ABOVE ALLOWS TO BLOW UP THE BASE AND THE BASE ONLY.
  # FIXME: We should save the projection \pi from the ambient space to the base space.
  # FIXME: This is also ties in with the model sections to be saved, see below. Should the base change, so do these sections...
  new_base = base_space(m)

  # Prepare ring map for the computation of the strict transform.
  # FIXME: This assume that I is generated by indeterminates! Very special!
  S = cox_ring(new_ambient_space)
  _e = eval_poly(coordinate_name, S)
  images = MPolyRingElem[]
  for v in gens(S)
    v == _e && continue
    if string(v) in [string(k) for k in gens(I)]
      push!(images, v * _e)
    else
      push!(images, v)
    end
  end
  ring_map = hom(base_ring(I), S, images)

  # Construct the new model
  if m isa GlobalTateModel
    new_pt = _my_proper_transform(ring_map, tate_polynomial(m), coordinate_name)
    model = GlobalTateModel(explicit_model_sections(m), defining_section_parametrization(m), new_pt, base_space(m), new_ambient_space)
  else
    new_pw = _my_proper_transform(ring_map, weierstrass_polynomial(m), coordinate_name)
    model = WeierstrassModel(explicit_model_sections(m), defining_section_parametrization(m), new_pw, base_space(m), new_ambient_space)
  end

  # Copy/overwrite known attributes from old model
  model_attributes = m.__attrs
  for (key, value) in model_attributes
    set_attribute!(model, key, value)
  end
  set_attribute!(model, :partially_resolved, true)

  # Return the model
  return model
end


@doc raw"""
    tune(m::AbstractFTheoryModel, p::MPolyRingElem; completeness_check::Bool = true)

Tune an F-theory model by replacing the hypersurface equation by a custom (polynomial)
equation. The latter can be any type of polynomial: a Tate polynomial, a Weierstrass
polynomial or a general polynomial. We do not conduct checks to tell which type the
provided polynomial is. Consequently, this tuning will always return a hypersurface model.

Note that there is less functionality for hypersurface models than for Weierstrass or Tate
models. For instance, `singular_loci` can (currently) not be computed for hypersurface models.

# Examples
```jldoctest
julia> B3 = projective_space(NormalToricVariety, 3)
Normal toric variety

julia> w = torusinvariant_prime_divisors(B3)[1]
Torus-invariant, prime divisor on a normal toric variety

julia> t = literature_model(arxiv_id = "1109.3454", equation = "3.1", base_space = B3, model_sections = Dict("w" => w), completeness_check = false)
Construction over concrete base may lead to singularity enhancement. Consider computing singular_loci. However, this may take time!

Global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> x1, x2, x3, x4, x, y, z = gens(parent(tate_polynomial(t)))
7-element Vector{MPolyDecRingElem{QQFieldElem, QQMPolyRingElem}}:
 x1
 x2
 x3
 x4
 x
 y
 z

julia> new_tate_polynomial = x^3 - y^2 - x * y * z * x4^4
-x4^4*x*y*z + x^3 - y^2

julia> tuned_t = tune(t, new_tate_polynomial)
Hypersurface model over a concrete base

julia> hypersurface_equation(tuned_t) == new_tate_polynomial
true

julia> base_space(tuned_t) == base_space(t)
true
```
"""
function tune(m::AbstractFTheoryModel, p::MPolyRingElem; completeness_check::Bool = true)
  entry_test = (m isa GlobalTateModel) || (m isa WeierstrassModel) || (m isa HypersurfaceModel)
  @req entry_test "Tuning currently supported only for Weierstrass, Tate and hypersurface models"
  @req (base_space(m) isa NormalToricVariety) "Currently, tuning is only supported for models over concrete toric bases"
  if m isa GlobalTateModel
    equation = tate_polynomial(m)
  elseif m isa WeierstrassModel
    equation = weierstrass_polynomial(m)
  else
    equation = hypersurface_equation(m)
  end
  @req parent(p) == parent(equation) "Parent mismatch between given and existing hypersurface polynomial"
  @req degree(p) == degree(equation) "Degree mismatch between given and existing hypersurface polynomial"
  p == equation && return m
  explicit_model_sections = Dict{String, MPolyRingElem}()
  gens_S = gens(parent(p))
  for k in 1:length(gens_S)
    explicit_model_sections[string(gens_S[k])] = gens_S[k]
  end
  tuned_model = HypersurfaceModel(explicit_model_sections, p, p, base_space(m), ambient_space(m), fiber_ambient_space(m))
  set_attribute!(tuned_model, :partially_resolved, false)
  return tuned_model
end



##########################################
### (2) Meta data setters
##########################################

function set_arxiv_id(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_id => desired_value)
end

function set_arxiv_doi(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_doi => desired_value)
end

function set_arxiv_link(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_link => desired_value)
end

function set_arxiv_model_equation_number(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_model_equation_number => desired_value)
end

function set_arxiv_model_page(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_model_page => desired_value)
end

function set_arxiv_model_section(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_model_section => desired_value)
end

function set_arxiv_version(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :arxiv_version => desired_value)
end

function set_associated_literature_models(m::AbstractFTheoryModel, desired_value::Vector{String})
  set_attribute!(m, :associated_literature_models => desired_value)
end

function set_journal_doi(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_doi => desired_value)
end

function set_journal_link(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_link => desired_value)
end

function set_journal_model_equation_number(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_model_equation_number => desired_value)
end

function set_journal_model_page(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_model_page => desired_value)
end

function set_journal_model_section(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_model_section => desired_value)
end

function set_journal_name(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_name => desired_value)
end

function set_journal_pages(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_pages => desired_value)
end

function set_journal_report_numbers(m::AbstractFTheoryModel, desired_value::Vector{String})
  set_attribute!(m, :journal_report_numbers => desired_value)
end

function set_journal_volume(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_volume => desired_value)
end

function set_journal_year(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :journal_year => desired_value)
end

function set_literature_identifier(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :literature_identifier => desired_value)
end

function set_model_description(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :model_description => desired_value)
end

function set_model_parameters(m::AbstractFTheoryModel, desired_value::Vector{String})
  set_attribute!(m, :model_parameters => desired_value)
end

function set_paper_authors(m::AbstractFTheoryModel, desired_value::Vector{String})
  set_attribute!(m, :paper_authors => desired_value)
end

function set_paper_buzzwords(m::AbstractFTheoryModel, desired_value::Vector{String})
  set_attribute!(m, :paper_buzzwords => desired_value)
end

function set_paper_description(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :paper_description => desired_value)
end

function set_paper_title(m::AbstractFTheoryModel, desired_value::String)
  set_attribute!(m, :paper_title => desired_value)
end

function set_related_literature_models(m::AbstractFTheoryModel, desired_value::Vector{String})
  set_attribute!(m, :related_literature_models => desired_value)
end



##########################################
### (3) Meta data adders
##########################################

function add_associated_literature_model(m::AbstractFTheoryModel, addition::String)
  values = has_associated_literature_models(m) ? associated_literature_models(m) : []
  !(addition in values) && set_attribute!(m, :associated_literature_models => vcat(values, [addition]))
end

function add_journal_report_number(m::AbstractFTheoryModel, addition::String)
  values = has_journal_report_numbers(m) ? journal_report_numbers(m) : []
  !(addition in values) && set_attribute!(m, :journal_report_numbers => vcat(values, [addition]))
end

function add_model_parameter(m::AbstractFTheoryModel, addition::String)
  values = has_model_parameters(m) ? model_parameters(m) : []
  !(addition in values) && set_attribute!(m, :model_parameters => vcat(values, [addition]))
end

function add_paper_author(m::AbstractFTheoryModel, addition::String)
  values = has_paper_authors(m) ? paper_authors(m) : []
  !(addition in values) && set_attribute!(m, :paper_authors => vcat(values, [addition]))
end

function add_paper_buzzword(m::AbstractFTheoryModel, addition::String)
  values = has_paper_buzzwords(m) ? paper_buzzwords(m) : []
  !(addition in values) && set_attribute!(m, :paper_buzzwords => vcat(values, [addition]))
end

function add_related_literature_model(m::AbstractFTheoryModel, addition::String)
  values = has_related_literature_models(m) ? related_literature_models(m) : []
  !(addition in values) && set_attribute!(m, :related_literature_models => vcat(values, [addition]))
end



##########################################
### (4) Specialized model data setters
##########################################

function set_generating_sections(m::AbstractFTheoryModel, vs::Vector{Vector{String}})
  R, _ = polynomial_ring(QQ, collect(keys(explicit_model_sections(m))))
  f = hom(R, cox_ring(base_space(m)), collect(values(explicit_model_sections(m))))
  set_attribute!(m, :generating_sections => [[f(eval_poly(l, R)) for l in k] for k in vs])
end

function set_resolutions(m::AbstractFTheoryModel, desired_value::Vector{Vector{Vector}})
  set_attribute!(m, :resolutions => desired_value)
end

function set_resolution_generating_sections(m::AbstractFTheoryModel, vs::Vector{Vector{Vector{Vector{String}}}})
  R, _ = polynomial_ring(QQ, collect(keys(explicit_model_sections(m))))
  f = hom(R, cox_ring(base_space(m)), collect(values(explicit_model_sections(m))))
  result = [[[[f(eval_poly(a, R)) for a in b] for b in c] for c in d] for d in vs]
  set_attribute!(m, :resolution_generating_sections => result)
end

function set_resolution_zero_sections(m::AbstractFTheoryModel, vs::Vector{Vector{Vector{String}}})
  R, _ = polynomial_ring(QQ, collect(keys(explicit_model_sections(m))))
  f = hom(R, cox_ring(base_space(m)), collect(values(explicit_model_sections(m))))
  result = [[[f(eval_poly(a, R)) for a in b] for b in c] for c in vs]
  set_attribute!(m, :resolution_zero_sections => result)
end

function set_weighted_resolutions(m::AbstractFTheoryModel, desired_value::Vector{Vector{Vector}})
  set_attribute!(m, :weighted_resolutions => desired_value)
end

function set_weighted_resolution_generating_sections(m::AbstractFTheoryModel, vs::Vector{Vector{Vector{Vector{String}}}})
  R, _ = polynomial_ring(QQ, collect(keys(explicit_model_sections(m))))
  f = hom(R, cox_ring(base_space(m)), collect(values(explicit_model_sections(m))))
  result = [[[[f(eval_poly(a, R)) for a in b] for b in c] for c in d] for d in vs]
  set_attribute!(m, :weighted_resolution_generating_sections => result)
end

function set_weighted_resolution_zero_sections(m::AbstractFTheoryModel, vs::Vector{Vector{Vector{String}}})
  R, _ = polynomial_ring(QQ, collect(keys(explicit_model_sections(m))))
  f = hom(R, cox_ring(base_space(m)), collect(values(explicit_model_sections(m))))
  result = [[[f(eval_poly(a, R)) for a in b] for b in c] for c in vs]
  set_attribute!(m, :weighted_resolution_zero_sections => result)
end

function set_zero_section(m::AbstractFTheoryModel, desired_value::Vector{String})
  R, _ = polynomial_ring(QQ, collect(keys(explicit_model_sections(m))))
  f = hom(R, cox_ring(base_space(m)), collect(values(explicit_model_sections(m))))
  set_attribute!(m, :zero_section => [f(eval_poly(l, R)) for l in desired_value])
end



##########################################
### (5) Specialized model data adders
##########################################

function add_generating_section(m::AbstractFTheoryModel, addition::Vector{String})
  values = has_generating_sections(m) ? related_literature_models(m) : []
  !(addition in values) && set_attribute!(m, :generating_sections => vcat(values, [addition]))
end

@doc raw"""
    add_resolution(m::AbstractFTheoryModel, centers::Vector{Vector{String}}, exceptionals::Vector{String})

Add a known resolution for a model.

```jldoctest
julia> m = literature_model(arxiv_id = "1109.3454", equation = "3.1")
Assuming that the first row of the given grading is the grading under Kbar

Global Tate model over a not fully specified base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> add_resolution(m, [["x", "y"], ["y", "s", "w"], ["s", "e4"], ["s", "e3"], ["s", "e1"]], ["s", "w", "e3", "e1", "e2"])

julia> length(resolutions(m))
2
```
"""
function add_resolution(m::AbstractFTheoryModel, centers::Vector{Vector{String}}, exceptionals::Vector{String})
  @req length(exceptionals) == length(centers) "Number of exceptionals must match number of centers"
  resolution = [centers, exceptionals]
  known_resolutions = has_resolutions(m) ? resolutions(m) : []
  !(resolution in known_resolutions) && set_attribute!(m, :resolutions => vcat(known_resolutions, [resolution]))
end

function add_resolution_generating_section(m::AbstractFTheoryModel, addition::Vector{Vector{Vector{String}}})
  values = has_resolution_generating_sections(m) ? resolution_generating_sections(m) : []
  !(addition in values) && set_attribute!(m, :resolution_generating_sections => vcat(values, [addition]))
end

function add_resolution_zero_section(m::AbstractFTheoryModel, addition::Vector{Vector{Vector{String}}})
  values = has_resolution_zero_sections(m) ? resolution_zero_sections(m) : []
  !(addition in values) && set_attribute!(m, :resolution_zero_sections => vcat(values, [addition]))
end

function add_weighted_resolution(m::AbstractFTheoryModel, addition::Vector{Vector})
  values = has_weighted_resolutions(m) ? weighted_resolutions(m) : []
  !(addition in values) && set_attribute!(m, :weighted_resolutions => vcat(values, [addition]))
end

function add_weighted_resolution_generating_section(m::AbstractFTheoryModel, addition::Vector{Vector{Vector{String}}})
  values = has_weighted_resolution_generating_sections(m) ? weighted_resolution_generating_sections(m) : []
  !(addition in values) && set_attribute!(m, :weighted_resolution_generating_sections => vcat(values, [addition]))
end

function add_weighted_resolution_zero_section(m::AbstractFTheoryModel, addition::Vector{Vector{Vector{String}}})
  values = has_weighted_resolution_zero_sections(m) ? weighted_resolution_zero_sections(m) : []
  !(addition in values) && set_attribute!(m, :weighted_resolution_zero_sections => vcat(values, [addition]))
end



##########################################
### (6) Specialized model methods
##########################################

@doc raw"""
    resolve(m::AbstractFTheoryModel, index::Int)

Resolve a model with the index-th resolution that is known.

Careful: Currently, this assumes that all blowups are toric blowups.
We hope to remove this requirement in the near future.

```jldoctest
julia> B3 = projective_space(NormalToricVariety, 3)
Normal toric variety

julia> w = torusinvariant_prime_divisors(B3)[1]
Torus-invariant, prime divisor on a normal toric variety

julia> t = literature_model(arxiv_id = "1109.3454", equation = "3.1", base_space = B3, model_sections = Dict("w" => w), completeness_check = false)
Construction over concrete base may lead to singularity enhancement. Consider computing singular_loci. However, this may take time!

Global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> t2 = resolve(t, 1)
Partially resolved global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> cox_ring(ambient_space(t2))
Multivariate polynomial ring in 12 variables over QQ graded by 
  x1 -> [1 0 0 0 0 0 0]
  x2 -> [0 1 0 0 0 0 0]
  x3 -> [0 1 0 0 0 0 0]
  x4 -> [0 1 0 0 0 0 0]
  x -> [0 0 1 0 0 0 0]
  y -> [0 0 0 1 0 0 0]
  z -> [0 0 0 0 1 0 0]
  e1 -> [0 0 0 0 0 1 0]
  e4 -> [0 0 0 0 0 0 1]
  e2 -> [-1 -3 -1 1 -1 -1 0]
  e3 -> [0 4 1 -1 1 0 -1]
  s -> [2 6 -1 0 2 1 1]
```
"""
function resolve(m::AbstractFTheoryModel, index::Int)
  entry_test = (m isa GlobalTateModel) || (m isa WeierstrassModel)
  @req entry_test "Resolve currently supported only for Weierstrass and Tate models"
  @req (base_space(m) isa NormalToricVariety) "Currently, resolve is only supported for models over concrete toric bases"
  @req has_attribute(m, :resolutions) "No resolutions known for this model"
  @req index > 0 "The resolution must be specified by a non-negative integer"
  @req index <= length(resolutions(m)) "The resolution must be specified by an integer that is not larger than the number of known resolutions"
  
  # Gather information for resolution
  centers, exceptionals = resolutions(m)[index]
  nr_blowups = length(centers)
  
  # Is this a sequence of toric blowups? (To be extended with @HechtiDerLachs and ToricSchemes).
  resolved_ambient_space = ambient_space(m)
  R, gR = polynomial_ring(QQ, vcat([string(g) for g in gens(cox_ring(resolved_ambient_space))], exceptionals))
  for center in centers
    blow_up_center = center
    if has_attribute(m, :explicit_model_sections)
      explicit_model_sections = get_attribute(m, :explicit_model_sections)
      for l in 1:length(blow_up_center)
        if haskey(explicit_model_sections, blow_up_center[l])
          new_locus = string(explicit_model_sections[blow_up_center[l]])
          blow_up_center[l] = new_locus
        end
      end
    end
    @req all(x -> x in gR, [eval_poly(p, R) for p in blow_up_center]) "Non-toric blowup currently not supported"
  end
  
  # If Tate model, use the new resolve function
  # FIXME: To be extended to Weierstrass and hypersurface models
  if m isa GlobalTateModel
    resolved_model = m
    for k in 1:nr_blowups
      # Center may involve base coordinates, subject to chosen base sections/variable names in the base. Adjust
      blow_up_center = centers[k]
      if has_attribute(resolved_model, :explicit_model_sections)
        explicit_model_sections = get_attribute(resolved_model, :explicit_model_sections)
        for l in 1:length(blow_up_center)
          if haskey(explicit_model_sections, blow_up_center[l])
            new_locus = string(explicit_model_sections[blow_up_center[l]])
            blow_up_center[l] = new_locus
          end
        end
      end
      resolved_model = blow_up(resolved_model, blow_up_center; coordinate_name = exceptionals[k])
    end
  else
    # Perform resolution
    for k in 1:nr_blowups
      S = cox_ring(resolved_ambient_space)
      resolved_ambient_space = domain(blow_up(resolved_ambient_space, ideal([eval_poly(g, S) for g in centers[k]]); coordinate_name = exceptionals[k]))
    end
    resolved_model = resolved_ambient_space
  end
  return resolved_model
end
