@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # WinForms handlers conventionally keep sender/eventArgs names.
        'PSAvoidAssignmentToAutomaticVariable'
        # Composition-root functions are not advanced cmdlets and must not prompt.
        'PSUseShouldProcessForStateChangingFunctions'
        # Event handler signatures intentionally keep unused parameters.
        'PSReviewUnusedParameter'
        # CLI scripts intentionally write host output.
        'PSAvoidUsingWriteHost'
        # Plural domain names such as Get-KapselFavorites are stable public names.
        'PSUseSingularNouns'
    )
}
