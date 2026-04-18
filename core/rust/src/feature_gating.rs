use crate::models::{
    AIAvailabilityReport, AIAvailabilityStatus, CapabilityTierId, FeatureGateContext,
    FeatureGateDecision, FeatureName, FeatureRequirement, PackCapability,
};
use std::collections::BTreeSet;

#[derive(Clone, Debug)]
pub struct AIAvailabilityGuard {
    requirements: Vec<FeatureRequirement>,
}

impl AIAvailabilityGuard {
    pub fn new(requirements: Vec<FeatureRequirement>) -> Self {
        Self { requirements }
    }

    pub fn requirements(&self) -> &[FeatureRequirement] {
        &self.requirements
    }

    pub fn evaluate(&self, feature: FeatureName, context: &FeatureGateContext) -> FeatureGateDecision {
        let requirement = self
            .requirements
            .iter()
            .find(|item| item.feature == feature)
            .cloned()
            .unwrap_or(FeatureRequirement {
                feature,
                minimum_tier: None,
                requires_pack_install: false,
                requires_online: false,
                requires_signed_entitlement: false,
                required_pack_capabilities: Vec::new(),
                allow_extractive_fallback: false,
            });

        self.evaluate_requirement(&requirement, context)
    }

    pub fn availability(&self, context: &FeatureGateContext) -> AIAvailabilityReport {
        let active_tier = effective_tier(context, true).or_else(|| highest_ready_pack_tier(context));
        let installed_capabilities = context
            .installed_packs
            .iter()
            .filter(|pack| pack.is_ready())
            .flat_map(|pack| pack.capabilities.iter().copied())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>();

        if let Some(pack) = best_ready_pack(context, true) {
            if pack.supports(&PackCapability::Generation) {
                return AIAvailabilityReport {
                    status: AIAvailabilityStatus::Ready,
                    reasons: vec!["A signed entitlement and verified local model pack are available.".into()],
                    active_tier,
                    installed_capabilities,
                };
            }
        }

        if context.extractive_fallback_available || !installed_capabilities.is_empty() {
            return AIAvailabilityReport {
                status: AIAvailabilityStatus::ExtractiveOnly,
                reasons: vec![
                    "Local extractive workflows remain available, but generative features are gated.".into(),
                ],
                active_tier,
                installed_capabilities,
            };
        }

        AIAvailabilityReport {
            status: AIAvailabilityStatus::Blocked,
            reasons: vec!["No verified local pack or extractive fallback is available.".into()],
            active_tier: None,
            installed_capabilities,
        }
    }

    fn evaluate_requirement(
        &self,
        requirement: &FeatureRequirement,
        context: &FeatureGateContext,
    ) -> FeatureGateDecision {
        let mut reasons = Vec::new();

        if requirement.requires_online && !context.network_available {
            reasons.push("An online connection is required.".into());
        }

        if requirement.requires_signed_entitlement && context.verified_entitlement.is_none() {
            reasons.push("A signed entitlement is required.".into());
        }

        let effective_tier = effective_tier(context, requirement.requires_signed_entitlement);
        if let Some(minimum_tier) = requirement.minimum_tier {
            if effective_tier.map(|tier| tier < minimum_tier).unwrap_or(true) {
                reasons.push(format!(
                    "Feature requires the {} tier or higher.",
                    minimum_tier.as_str()
                ));
            }
        }

        if requirement.requires_pack_install {
            match best_ready_pack(context, requirement.requires_signed_entitlement) {
                Some(pack) => {
                    for capability in &requirement.required_pack_capabilities {
                        if !pack.supports(capability) {
                            reasons.push(format!(
                                "Installed pack does not support {}.",
                                capability.as_str()
                            ));
                        }
                    }
                }
                None => reasons.push("A verified local model pack is required.".into()),
            }
        }

        let can_run_extractively =
            !reasons.is_empty() && requirement.allow_extractive_fallback && context.extractive_fallback_available;

        FeatureGateDecision {
            allowed: reasons.is_empty(),
            feature: requirement.feature,
            reasons,
            required_tier: requirement.minimum_tier,
            can_run_extractively,
        }
    }
}

impl Default for AIAvailabilityGuard {
    fn default() -> Self {
        Self::new(default_feature_requirements())
    }
}

pub fn default_feature_requirements() -> Vec<FeatureRequirement> {
    vec![
        FeatureRequirement {
            feature: FeatureName::InstantMode,
            minimum_tier: Some(CapabilityTierId::QuickStart),
            requires_pack_install: true,
            requires_online: false,
            requires_signed_entitlement: true,
            required_pack_capabilities: vec![PackCapability::Generation],
            allow_extractive_fallback: true,
        },
        FeatureRequirement {
            feature: FeatureName::SourceBackedQa,
            minimum_tier: Some(CapabilityTierId::QuickStart),
            requires_pack_install: false,
            requires_online: false,
            requires_signed_entitlement: false,
            required_pack_capabilities: Vec::new(),
            allow_extractive_fallback: true,
        },
        FeatureRequirement {
            feature: FeatureName::PublicLawSearch,
            minimum_tier: None,
            requires_pack_install: false,
            requires_online: true,
            requires_signed_entitlement: false,
            required_pack_capabilities: Vec::new(),
            allow_extractive_fallback: false,
        },
        FeatureRequirement {
            feature: FeatureName::LongDocumentAnalysis,
            minimum_tier: Some(CapabilityTierId::CaseAssociate),
            requires_pack_install: true,
            requires_online: false,
            requires_signed_entitlement: true,
            required_pack_capabilities: vec![PackCapability::Generation, PackCapability::Embeddings],
            allow_extractive_fallback: true,
        },
        FeatureRequirement {
            feature: FeatureName::AdvancedDrafting,
            minimum_tier: Some(CapabilityTierId::SeniorDrafting),
            requires_pack_install: true,
            requires_online: false,
            requires_signed_entitlement: true,
            required_pack_capabilities: vec![PackCapability::Generation, PackCapability::Bilingual],
            allow_extractive_fallback: false,
        },
        FeatureRequirement {
            feature: FeatureName::BilingualMode,
            minimum_tier: Some(CapabilityTierId::CaseAssociate),
            requires_pack_install: true,
            requires_online: false,
            requires_signed_entitlement: true,
            required_pack_capabilities: vec![PackCapability::Bilingual],
            allow_extractive_fallback: false,
        },
    ]
}

fn highest_ready_pack_tier(context: &FeatureGateContext) -> Option<CapabilityTierId> {
    context
        .installed_packs
        .iter()
        .filter(|pack| pack.is_ready())
        .map(|pack| pack.capability_tier_id)
        .max()
}

fn best_ready_pack<'a>(
    context: &'a FeatureGateContext,
    requires_signed_entitlement: bool,
) -> Option<&'a crate::models::InstalledModelPack> {
    let entitled_rank = if requires_signed_entitlement {
        context
            .verified_entitlement
            .as_ref()
            .and_then(|entitlement| entitlement.claims.highest_allowed_tier())
            .map(|tier| tier.rank())
    } else {
        None
    };

    context
        .installed_packs
        .iter()
        .filter(|pack| pack.is_ready())
        .filter(|pack| {
            if let Some(rank) = entitled_rank {
                pack.capability_tier_id.rank() <= rank
            } else {
                !requires_signed_entitlement || context.verified_entitlement.is_some()
            }
        })
        .max_by_key(|pack| pack.capability_tier_id.rank())
}

fn effective_tier(
    context: &FeatureGateContext,
    requires_signed_entitlement: bool,
) -> Option<CapabilityTierId> {
    let installed = highest_ready_pack_tier(context);
    if !requires_signed_entitlement {
        return installed.or_else(|| {
            context
                .verified_entitlement
                .as_ref()
                .and_then(|entitlement| entitlement.claims.highest_allowed_tier())
        });
    }

    match (
        installed,
        context
            .verified_entitlement
            .as_ref()
            .and_then(|entitlement| entitlement.claims.highest_allowed_tier()),
    ) {
        (Some(installed), Some(entitled)) => Some(std::cmp::min(installed, entitled)),
        _ => None,
    }
}
