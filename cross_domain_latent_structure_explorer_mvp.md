# Cross-Domain Latent Structure Explorer
## MVP Research Spec

### Working idea

Large language models may encode recurring abstract structures across unrelated domains in similar internal representations.

For example, the surface vocabulary of these concepts differs dramatically:

- ecosystem collapse
- bank runs
- neural attractor failure
- phase transitions
- cascading network failures

Yet each may share deeper relational properties such as:

- local interactions
- resource or state constraints
- positive and negative feedback
- delayed response
- metastability
- threshold behavior
- nonlinear transition
- path dependence

The hypothesis is that an LLM may partially compress these cross-domain similarities into shared latent geometry.

The objective of this project is to test whether those shared structures can be detected, validated, and eventually used to generate novel cross-domain associations that humans have not explicitly specified.

---

# 1. Core Research Question

**Can an open-weight LLM independently encode the same abstract relational structure when that structure is described using unrelated vocabulary from different scientific or conceptual domains?**

If yes, the next question becomes:

**Can we search those representations for unexpected cross-domain neighbors and use them to generate novel, testable ideas?**

The long-term possibility is that LLMs contain latent abstractions richer than the explicit language used to train them.

Rather than treating this only as an interpretability problem, we would use the model as a:

> **cross-disciplinary structure detector**

---

# 2. Why This Is Interesting

Human creativity frequently comes from cross-domain transfer.

Examples:

- Darwin mapping selective pressure onto biological change
- Newton linking terrestrial falling objects with celestial motion
- information theory moving between communication, biology, computation, and physics
- evolutionary concepts appearing in economics and optimization
- network theory spanning epidemiology, finance, biology, and communications

Humans are limited by how many fields any one person can understand deeply.

An LLM has encountered language from thousands of domains.

If the model has internally compressed structurally similar relationships across those domains, its latent space may expose patterns that are difficult for humans to notice because terminology and disciplinary boundaries obscure them.

The goal is not merely to discover analogies.

The goal is to discover **structural correspondences that transfer predictions or methods between domains**.

---

# 3. Key Distinction: Analogy vs. Structural Reuse

A weak result:

> “Economies are like ecosystems.”

A strong result:

> “These systems share a specific latent representation characterized by delayed positive feedback, resource depletion, local competition, and abrupt threshold transition.”

A much stronger result:

> “A mathematical or causal relationship used in Domain A maps onto Domain B and predicts a previously untested behavior.”

That final step moves the project from interpretability into discovery.

---

# 4. MVP Strategy

We should not begin by attempting to map the entire latent space.

Instead:

> **Behavioral discovery → latent confirmation → causal intervention → cross-domain prediction**

This keeps the initial experiment small and falsifiable.

---

# 5. Phase 1 — Positive-Control Experiment

Create a set of known cross-domain structural analogies.

Example families:

### Family A — Cascading Failure
- electrical grid cascade
- bank run
- ecosystem collapse
- supply-chain failure
- epidemic spread
- neural runaway activity

### Family B — Competitive Selection
- biological natural selection
- market competition
- evolutionary algorithms
- immune clonal selection
- reinforcement learning policy selection

### Family C — Attractor / Stable State
- protein folding
- neural attractors
- economic equilibria
- ecological stable states
- optimization minima

### Family D — Threshold / Phase Change
- physical phase transition
- social tipping point
- critical mass in network adoption
- ecological regime shift
- financial liquidity collapse

### Family E — Redundancy / Resilience
- genetic redundancy
- fault-tolerant systems
- diversified portfolios
- distributed computing
- ecological biodiversity

For each family, create examples written with strongly domain-specific vocabulary.

Also create negative controls that appear linguistically similar but are structurally different.

The first success criterion:

> Known structural analogies should appear measurably closer in internal representation than carefully matched negative controls.

---

# 6. Open Model

Start with a capable but manageable open-weight model.

Candidates:

- Qwen family
- Gemma family
- Llama family
- another strong 7B–14B parameter open model

Requirements:

- full access to model weights
- PyTorch-compatible
- ability to hook intermediate activations
- good multilingual / scientific corpus exposure
- manageable VRAM footprint

A 7B–14B model is preferable for MVP because we are probing representations, not trying to maximize benchmark performance.

---

# 7. Instrumentation

Core stack:

- Python
- PyTorch
- Hugging Face Transformers
- optional TransformerLens where compatible
- NumPy / SciPy
- scikit-learn
- optional SAE tooling later
- Supabase/Postgres + pgvector for persistent experimental results
- GitHub for code/versioning

We capture selected representations such as:

- token embeddings
- residual stream activations
- MLP outputs
- attention outputs
- selected hidden states by layer

We should avoid storing every activation from every layer indefinitely.

Instead:

1. capture
2. summarize/project
3. persist reduced representations
4. discard unnecessary raw tensors

---

# 8. Representational Comparison Methods

Initial methods:

- cosine similarity
- centered kernel alignment (CKA)
- canonical correlation analysis (CCA)
- representational similarity analysis (RSA)
- PCA / SVD
- clustering
- nearest-neighbor search
- linear probes
- subspace comparison

Important:

We should not assume the interesting structure will be represented by a single neuron or single vector.

The relevant object may be:

- a direction
- a subspace
- a collection of features
- a pattern distributed across multiple layers
- a trajectory through successive transformer layers

---

# 9. Removing Surface Vocabulary

A major confound is simple lexical similarity.

We should deliberately test representations using several versions of the same structure:

### Version 1
Natural domain-specific description.

### Version 2
Paraphrase with different vocabulary.

### Version 3
Abstract relational description with domain nouns removed.

Example:

Instead of:

> A bank experiences deposit withdrawals that force asset sales, which lower asset prices and trigger further withdrawals.

Use:

> A system contains agents that withdraw a shared resource. Their actions reduce system stability, causing additional agents to perform the same action, producing self-amplifying failure.

If latent similarity survives vocabulary removal and paraphrasing, that is much stronger evidence for structural representation.

---

# 10. Frontier Model as Researcher

A frontier closed model would act as theorist and critic.

It would not need direct access to billions of weights.

It receives summarized experimental artifacts:

- activation clusters
- nearest-neighbor examples
- layer comparisons
- feature descriptions
- cross-domain matches
- intervention outcomes
- statistical significance
- failed hypotheses

Example prompt to the investigator model:

> These passages from biology, economics, physics, and computer science activate a shared latent subspace. Describe the common relational structure without using domain-specific nouns. Propose three explanations for why the model represents them similarly. Then propose discriminating experiments.

This creates a recursive loop:

```text
OPEN MODEL
   ↓
activation capture
   ↓
feature / similarity database
   ↓
FRONTIER MODEL
   ↓
hypothesis
   ↓
experiment generator
   ↓
OPEN MODEL
   ↓
results
   ↺
```

---

# 11. Phase 2 — Unsupervised Discovery

Once positive controls work, reverse the process.

Instead of specifying analogous concepts:

1. feed a broad cross-domain corpus
2. compute representations
3. search for unexpected nearest neighbors across domains
4. exclude obvious lexical/topic overlap
5. rank surprising structural matches
6. ask the investigator model to explain the shared abstraction
7. design tests

This is the point where the project becomes genuinely interesting.

Possible output:

> A representation used in protein folding repeatedly appears in descriptions of financial liquidity and social coordination.

That alone is not enough.

The system then asks:

> What exact relational property explains the overlap?

---

# 12. Phase 3 — Causal Intervention

Correlation in latent space is not sufficient.

If we identify a candidate shared feature/subspace, we intervene.

Possible techniques:

- activation steering
- feature suppression
- feature amplification
- activation patching
- ablation
- representation replacement
- sparse-autoencoder feature manipulation

Example:

If a feature appears to encode “self-amplifying threshold collapse”:

1. suppress it during reasoning about bank runs
2. suppress it during reasoning about ecosystem collapse
3. measure whether the model loses the same class of reasoning in both domains

If behavior changes similarly across domains, that is evidence that the feature is genuinely domain-general.

---

# 13. Phase 4 — Transfer Test

The most important experiment:

> Can a structure or mathematical method from one domain improve prediction or explanation in another?

Process:

1. identify cross-domain latent correspondence
2. extract the implied relational structure
3. identify a mature theory/tool in Domain A
4. transfer it to Domain B
5. derive a novel prediction
6. test against data or literature not included in the original discovery step

This is the threshold between:

- interesting representation analysis

and

- potentially novel research.

---

# 14. Potential Discovery Categories

We should actively search for recurring structures involving:

### Feedback
- reinforcing loops
- balancing loops
- delayed feedback
- runaway dynamics

### Constraints
- conservation
- scarcity
- bottlenecks
- capacity limits

### Thresholds
- tipping points
- criticality
- phase transitions
- discontinuities

### Search / Selection
- evolutionary landscapes
- optimization
- competition
- adaptation

### Networks
- contagion
- centrality
- redundancy
- cascading failure
- information flow

### Temporal Structure
- hysteresis
- path dependence
- delayed effects
- irreversible transitions

### Information
- compression
- noise
- signaling
- error correction
- redundancy

### Agency
- incentives
- strategic response
- coordination
- adversarial interaction

---

# 15. Database Schema — Initial Concept

A simple research schema could include:

### `experiments`
- id
- model
- model_version
- hypothesis
- corpus_version
- methodology
- status
- created_at

### `samples`
- id
- domain
- source_text
- abstracted_text
- structural_family
- control_type
- metadata

### `representations`
- sample_id
- model_layer
- representation_type
- vector_reference
- reduced_vector
- projection_method

### `matches`
- sample_a
- sample_b
- similarity
- cross_domain
- lexical_similarity
- novelty_score
- investigator_summary

### `hypotheses`
- statement
- supporting_matches
- proposed_structure
- confidence
- falsification_test
- status

### `interventions`
- hypothesis_id
- feature_or_subspace
- intervention_type
- expected_effect
- observed_effect
- result

This is enough for MVP.

---

# 16. UI — Keep It Minimal

The initial UI should be a research console, not a consumer product.

Useful views:

### Experiment
- hypothesis
- corpus
- model
- layer
- metrics
- status

### Cross-Domain Matches
- Domain A passage
- Domain B passage
- similarity
- lexical similarity
- layer
- model-generated structural explanation

### Latent Neighborhood
Given one sample:

> show nearest examples from entirely different domains.

### Hypothesis
- proposed common structure
- supporting evidence
- opposing evidence
- proposed causal test
- intervention results

### Discovery Feed
Rank unusual cross-domain matches by:

- high latent similarity
- low lexical similarity
- large domain distance
- reproducibility across models/layers

---

# 17. Compute Strategy

We do **not** need dedicated hardware initially.

Start with whatever GPU-backed environment is available.

If the model fits and inference speed is reasonable, MVP work can happen without RunPod.

Dedicated cloud GPU becomes useful when we need:

- larger models
- tens of thousands of samples
- many simultaneous layers
- SAE training
- large intervention sweeps
- multiple model comparisons

At that point, use:

- RunPod
- Lambda
- Vast.ai
- another hourly GPU provider

No reason to purchase hardware initially.

---

# 18. Expected Costs

Rough MVP estimate:

### Toy Proof of Concept
- 1 open model
- 100–500 samples
- selected layers
- similarity analysis

Estimated external compute/API cost:

**$0–$150**

depending on available local/environment GPU access.

### Serious MVP
- 5k–25k passages
- multiple layers
- dimensionality reduction
- frontier-model interpretation
- repeated experiments

Estimated:

**$300–$1,000**

### Expanded Research Run
- multiple open models
- SAE training
- large cross-domain corpus
- causal interventions
- automated hypothesis loops

Estimated:

**$2,000–$10,000**

These are planning estimates, not fixed requirements.

---

# 19. MVP Success Criteria

The project is interesting if we can demonstrate:

### Level 1
Known cross-domain structural analogies cluster more strongly than negative controls.

### Level 2
The effect survives paraphrasing and domain-vocabulary removal.

### Level 3
The same structure appears across multiple layers and/or models.

### Level 4
A causal intervention affects reasoning similarly across multiple domains.

### Level 5
The system discovers an unexpected cross-domain association not supplied by us.

### Level 6
The discovered relationship transfers a useful method, prediction, or explanatory model from one field into another.

Level 6 is the real prize.

---

# 20. What We Are NOT Building Yet

Not part of MVP:

- public crowdsourcing
- voting systems
- Wikipedia-style hypothesis repository
- generalized agent society
- full latent-space mapping
- model self-modification
- autonomous publishing
- massive multi-agent debate system

The first question is much narrower:

> **Can we find useful hidden structural correspondences inside an existing LLM?**

---

# 21. Possible Later Direction — Language Primitives

If recurring cross-domain latent structures are robust, a second research direction becomes possible.

Ask:

> Does the model repeatedly represent an abstract relationship for which natural language has no compact expression?

If so, those structures could become candidates for:

- new semantic primitives
- visual notation
- machine-native reasoning notation
- hybrid human/AI language
- better representations for scientific reasoning

This may eventually connect to the idea that improved representations can enable improved thought.

But it should be downstream of the cross-domain experiment, not the initial objective.

---

# 22. Connection to the Earlier AdS/CFT Work

There is a conceptual similarity to the earlier transformer experiments around AdS/CFT:

> Can a transformer learn a useful hidden representation of a difficult conceptual space?

But this project is substantially simpler.

In the AdS/CFT work, the challenge was asking a model to learn representations from specialized or synthetic physics data.

Here:

> the representation already exists inside a capable pretrained LLM.

We are probing it rather than creating it.

If this work eventually produces genuinely useful representational primitives or a richer reasoning language, it may be interesting to revisit difficult theoretical-physics domains such as AdS/CFT with that machinery.

---

# 23. First Build

The first implementation should be deliberately small.

### Model
One 7B–14B open-weight model.

### Domains
Start with four:

- biology
- economics
- physics
- computer science

### Structural Families
Start with five:

- cascading failure
- competitive selection
- attractor/stable state
- threshold transition
- redundancy/resilience

### Dataset
Approximately:

- 25 positive examples per domain/family
- matched paraphrases
- negative controls

Rough total:

**500–1,500 samples**

### Layers
Probe a small subset:

- early
- early-middle
- middle
- late-middle
- late

### Output
Answer one question:

> **Can we distinguish domain-independent structural similarity from vocabulary/topic similarity in the model’s internal representations?**

If yes, expand.

---

# 24. Working Principle

The project should follow a simple discipline:

> **Do not reward interesting analogies. Reward transferable structure.**

And the research loop:

> **Find → abstract → test → intervene → transfer.**

That is the MVP.
