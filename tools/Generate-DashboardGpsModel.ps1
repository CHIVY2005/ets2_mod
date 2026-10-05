<#
.SYNOPSIS
    Generates realistic 3D dashboard GPS monitor models (casing + opaque LCD screen)
    for passenger bus trucks (Kia, Kim Long, Thaco).
#>
param(
    [string[]]$TruckFamilies = @('kia', 'kimlong', 'thaco'),
    [double]$Width = 0.40,
    [double]$Height = 0.25,
    [double]$Depth = 0.025,
    [double]$Bezel = 0.02
)

$ErrorActionPreference = 'Stop'

function Hex-FromFloat([single]$value) {
    $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes($value), 0)
    return $bits.ToString('x8')
}

function Build-MonitorModel {
    param(
        [double]$W,
        [double]$H,
        [double]$D,
        [double]$B
    )

    # Base centers: Optical HUD center + offset (dX=+0.65, dY=+0.20, dZ=+2.60)
    $Cx = 3.28824353218079 + 0.65
    $Cy = -1.90535873174667 + 0.20
    $Cz = -7.94101595878601 + 2.60

    # Basis vectors
    # Normal facing driver
    $Nx = -0.4092408; $Ny = 0.0684534; $Nz = 0.9098522
    # Screen width axis
    $Rx =  0.9118915; $Ry = 0.0000000; $Rz = 0.4104314
    # Screen height axis
    $Ux =  0.0280877; $Uy = 0.9976544; $Uz = -0.0624103

    $hw = [double]($W / 2.0)
    $hh = [double]($H / 2.0)
    $hws = [double]($hw - $B)
    $hhs = [double]($hh - $B)

    # Screen surface at n = 0 (exact test line of sight)
    # Bezel rim protrudes slightly in front at n = +0.004 m
    # Casing back extends behind at n = -($D - 0.004) m
    $nBezel = [double]0.004
    $nBack  = [double](-1.0 * ($D - 0.004))

    # Helper function at top-level of Build-MonitorModel
    $P = {
        param([double]$r, [double]$u, [double]$n)
        $x = [single]($Cx + $r * $Rx + $u * $Ux + $n * $Nx)
        $y = [single]($Cy + $r * $Ry + $u * $Uy + $n * $Ny)
        $z = [single]($Cz + $r * $Rz + $u * $Uz + $n * $Nz)
        return ,@($x, $y, $z)
    }

    # --- PIECE 0: Screen (eut2.dif.lum) ---
    # 0: TL, 1: TR, 2: BR, 3: BL
    # All at n = 0 so Piece 0 center is exactly (Cx, Cy, Cz)
    $s0 = (& $P (-$hws) ( $hhs) 0.0)
    $s1 = (& $P ( $hws) ( $hhs) 0.0)
    $s2 = (& $P ( $hws) (-$hhs) 0.0)
    $s3 = (& $P (-$hws) (-$hhs) 0.0)
    $screenPos = @($s0, $s1, $s2, $s3)

    $screenNorm = @([single]$Nx, [single]$Ny, [single]$Nz)
    $screenUV = @(
        @([single]0.0, [single]0.625),
        @([single]1.0, [single]0.625),
        @([single]1.0, [single]0.0),
        @([single]0.0, [single]0.0)
    )
    $screenTri = @(
        @(0, 1, 2),
        @(0, 2, 3)
    )

    # --- PIECE 1: Casing Box & Bezel (eut2.dif.spec) ---
    $casingVertices = [Collections.Generic.List[pscustomobject]]::new()
    $casingTriangles = [Collections.Generic.List[int[]]]::new()

    $AddQuad = {
        param($v0, $v1, $v2, $v3, $norm)
        $baseIdx = $casingVertices.Count
        $casingVertices.Add([pscustomobject]@{ Pos = $v0; Norm = $norm; UV = @([single]0.02, [single]0.45) })
        $casingVertices.Add([pscustomobject]@{ Pos = $v1; Norm = $norm; UV = @([single]0.08, [single]0.45) })
        $casingVertices.Add([pscustomobject]@{ Pos = $v2; Norm = $norm; UV = @([single]0.08, [single]0.35) })
        $casingVertices.Add([pscustomobject]@{ Pos = $v3; Norm = $norm; UV = @([single]0.02, [single]0.35) })
        $casingTriangles.Add([int[]]@($baseIdx, ($baseIdx + 1), ($baseIdx + 2)))
        $casingTriangles.Add([int[]]@($baseIdx, ($baseIdx + 2), ($baseIdx + 3)))
    }

    $nFront = @([single]$Nx, [single]$Ny, [single]$Nz)
    $nBackNorm  = @([single]-$Nx, [single]-$Ny, [single]-$Nz)
    $nTop   = @([single]$Ux, [single]$Uy, [single]$Uz)
    $nBot   = @([single]-$Ux, [single]-$Uy, [single]-$Uz)
    $nRight = @([single]$Rx, [single]$Ry, [single]$Rz)
    $nLeft  = @([single]-$Rx, [single]-$Ry, [single]-$Rz)

    # Front bezel outer points (at n = +nBezel)
    $FO_TL = (& $P (-$hw) ( $hh) $nBezel)
    $FO_TR = (& $P ( $hw) ( $hh) $nBezel)
    $FO_BR = (& $P ( $hw) (-$hh) $nBezel)
    $FO_BL = (& $P (-$hw) (-$hh) $nBezel)

    # Front bezel inner points (flush with screen at n = 0)
    $FI_TL = (& $P (-$hws) ( $hhs) 0.0)
    $FI_TR = (& $P ( $hws) ( $hhs) 0.0)
    $FI_BR = (& $P ( $hws) (-$hhs) 0.0)
    $FI_BL = (& $P (-$hws) (-$hhs) 0.0)

    # Back outer points (at n = nBack)
    $BO_TL = (& $P (-$hw) ( $hh) $nBack)
    $BO_TR = (& $P ( $hw) ( $hh) $nBack)
    $BO_BR = (& $P ( $hw) (-$hh) $nBack)
    $BO_BL = (& $P (-$hw) (-$hh) $nBack)

    # 1) Front Bezel (4 quads)
    & $AddQuad $FO_TL $FO_TR $FI_TR $FI_TL $nFront
    & $AddQuad $FI_BL $FI_BR $FO_BR $FO_BL $nFront
    & $AddQuad $FO_TL $FI_TL $FI_BL $FO_BL $nFront
    & $AddQuad $FI_TR $FO_TR $FO_BR $FI_BR $nFront

    # 2) Outer Sides (4 quads)
    & $AddQuad $BO_TL $BO_TR $FO_TR $FO_TL $nTop
    & $AddQuad $FO_BL $FO_BR $BO_BR $BO_BL $nBot
    & $AddQuad $BO_TL $FO_TL $FO_BL $BO_BL $nLeft
    & $AddQuad $FO_TR $BO_TR $BO_BR $FO_BR $nRight

    # 3) Back cover (1 quad)
    & $AddQuad $BO_TR $BO_TL $BO_BL $BO_BR $nBackNorm

    # Generate PIM content
    $sb = [Text.StringBuilder]::new()
    $sb.AppendLine("Header {") | Out-Null
    $sb.AppendLine("    FormatVersion: 5") | Out-Null
    $sb.AppendLine('    Source: "Blender 3.6.14 (hash: e480a2c4465b), SCS Blender Tools: 2.4.1909305e"') | Out-Null
    $sb.AppendLine('    Type: "Model"') | Out-Null
    $sb.AppendLine('    Name: "dashboard_gps"') | Out-Null
    $sb.AppendLine("}") | Out-Null
    $sb.AppendLine("Global {") | Out-Null
    $totalV = 4 + $casingVertices.Count
    $totalT = 2 + $casingTriangles.Count
    $sb.AppendLine("    VertexCount: $totalV") | Out-Null
    $sb.AppendLine("    TriangleCount: $totalT") | Out-Null
    $sb.AppendLine("    MaterialCount: 2") | Out-Null
    $sb.AppendLine("    PieceCount: 2") | Out-Null
    $sb.AppendLine("    PartCount: 1") | Out-Null
    $sb.AppendLine("    BoneCount: 0") | Out-Null
    $sb.AppendLine("    LocatorCount: 0") | Out-Null
    $sb.AppendLine('    Skeleton: "optical_hud.pis"') | Out-Null
    $sb.AppendLine("    PieceSkinCount: 0") | Out-Null
    $sb.AppendLine("}") | Out-Null
    $sb.AppendLine("Material {") | Out-Null
    $sb.AppendLine("    Index: 0") | Out-Null
    $sb.AppendLine('    Alias: "mat_screen"') | Out-Null
    $sb.AppendLine('    Effect: "eut2.dif.lum"') | Out-Null
    $sb.AppendLine("}") | Out-Null
    $sb.AppendLine("Material {") | Out-Null
    $sb.AppendLine("    Index: 1") | Out-Null
    $sb.AppendLine('    Alias: "mat_casing"') | Out-Null
    $sb.AppendLine('    Effect: "eut2.dif.spec"') | Out-Null
    $sb.AppendLine("}") | Out-Null

    # Piece 0: Screen
    $sb.AppendLine("Piece {") | Out-Null
    $sb.AppendLine("    Index: 0") | Out-Null
    $sb.AppendLine("    Material: 0") | Out-Null
    $sb.AppendLine("    VertexCount: 4") | Out-Null
    $sb.AppendLine("    TriangleCount: 2") | Out-Null
    $sb.AppendLine("    StreamCount: 4") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT3") | Out-Null
    $sb.AppendLine('        Tag: "_POSITION"') | Out-Null
    for ($i = 0; $i -lt 4; $i++) {
        $pos = $screenPos[$i]
        $sb.AppendLine(('        {0,-4} ( &{1}  &{2}  &{3} )' -f $i, (Hex-FromFloat $pos[0]), (Hex-FromFloat $pos[1]), (Hex-FromFloat $pos[2]))) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT3") | Out-Null
    $sb.AppendLine('        Tag: "_NORMAL"') | Out-Null
    for ($i = 0; $i -lt 4; $i++) {
        $sb.AppendLine(('        {0,-4} ( &{1}  &{2}  &{3} )' -f $i, (Hex-FromFloat $screenNorm[0]), (Hex-FromFloat $screenNorm[1]), (Hex-FromFloat $screenNorm[2]))) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT2") | Out-Null
    $sb.AppendLine('        Tag: "_UV0"') | Out-Null
    $sb.AppendLine("        AliasCount: 1") | Out-Null
    $sb.AppendLine('        Aliases: "_TEXCOORD0"') | Out-Null
    for ($i = 0; $i -lt 4; $i++) {
        $uv = $screenUV[$i]
        $sb.AppendLine(('        {0,-4} ( &{1}  &{2} )' -f $i, (Hex-FromFloat $uv[0]), (Hex-FromFloat $uv[1]))) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT4") | Out-Null
    $sb.AppendLine('        Tag: "_RGBA"') | Out-Null
    $oneHex = Hex-FromFloat 1.0
    for ($i = 0; $i -lt 4; $i++) {
        $sb.AppendLine(('        {0,-4} ( &{1}  &{1}  &{1}  &{1} )' -f $i, $oneHex)) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Triangles {") | Out-Null
    for ($i = 0; $i -lt 2; $i++) {
        $t = $screenTri[$i]
        $sb.AppendLine(('        {0,-4} ( {1}  {2}  {3} )' -f $i, $t[0], $t[1], $t[2])) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("}") | Out-Null

    # Piece 1: Casing
    $sb.AppendLine("Piece {") | Out-Null
    $sb.AppendLine("    Index: 1") | Out-Null
    $sb.AppendLine("    Material: 1") | Out-Null
    $sb.AppendLine("    VertexCount: $($casingVertices.Count)") | Out-Null
    $sb.AppendLine("    TriangleCount: $($casingTriangles.Count)") | Out-Null
    $sb.AppendLine("    StreamCount: 4") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT3") | Out-Null
    $sb.AppendLine('        Tag: "_POSITION"') | Out-Null
    for ($i = 0; $i -lt $casingVertices.Count; $i++) {
        $pos = $casingVertices[$i].Pos
        $sb.AppendLine(('        {0,-4} ( &{1}  &{2}  &{3} )' -f $i, (Hex-FromFloat $pos[0]), (Hex-FromFloat $pos[1]), (Hex-FromFloat $pos[2]))) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT3") | Out-Null
    $sb.AppendLine('        Tag: "_NORMAL"') | Out-Null
    for ($i = 0; $i -lt $casingVertices.Count; $i++) {
        $norm = $casingVertices[$i].Norm
        $sb.AppendLine(('        {0,-4} ( &{1}  &{2}  &{3} )' -f $i, (Hex-FromFloat $norm[0]), (Hex-FromFloat $norm[1]), (Hex-FromFloat $norm[2]))) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT2") | Out-Null
    $sb.AppendLine('        Tag: "_UV0"') | Out-Null
    $sb.AppendLine("        AliasCount: 1") | Out-Null
    $sb.AppendLine('        Aliases: "_TEXCOORD0"') | Out-Null
    for ($i = 0; $i -lt $casingVertices.Count; $i++) {
        $uv = $casingVertices[$i].UV
        $sb.AppendLine(('        {0,-4} ( &{1}  &{2} )' -f $i, (Hex-FromFloat $uv[0]), (Hex-FromFloat $uv[1]))) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Stream {") | Out-Null
    $sb.AppendLine("        Format: FLOAT4") | Out-Null
    $sb.AppendLine('        Tag: "_RGBA"') | Out-Null
    for ($i = 0; $i -lt $casingVertices.Count; $i++) {
        $sb.AppendLine(('        {0,-4} ( &{1}  &{1}  &{1}  &{1} )' -f $i, $oneHex)) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("    Triangles {") | Out-Null
    for ($i = 0; $i -lt $casingTriangles.Count; $i++) {
        $t = $casingTriangles[$i]
        $sb.AppendLine(('        {0,-4} ( {1}  {2}  {3} )' -f $i, $t[0], $t[1], $t[2])) | Out-Null
    }
    $sb.AppendLine("    }") | Out-Null
    $sb.AppendLine("}") | Out-Null

    # Part
    $sb.AppendLine("Part {") | Out-Null
    $sb.AppendLine('    Name: "defaultpart"') | Out-Null
    $sb.AppendLine("    PieceCount: 2") | Out-Null
    $sb.AppendLine("    LocatorCount: 0") | Out-Null
    $sb.AppendLine("    Pieces: 0 1") | Out-Null
    $sb.AppendLine("    Locators:") | Out-Null
    $sb.AppendLine("}") | Out-Null

    # Generate PIT content
    $pit = @"
# Look Names:
#	default
#
# Variant Names:
#	default
#
Header {
    FormatVersion: 1
    Source: "Blender 3.6.14 (hash: e480a2c4465b), SCS Blender Tools: 2.4.1909305e"
    Type: "Trait"
    Name: "dashboard_gps"
}
Global {
    LookCount: 1
    VariantCount: 1
    PartCount: 1
    MaterialCount: 2
}
Look {
    Name: "default"
    Material {
        Alias: "mat_screen"
        Effect: "eut2.dif.lum"
        Flags: 0
        AttributeCount: 6
        TextureCount: 1
        Attribute {
            Format: FLOAT3
            Tag: "diffuse"
            Value: ( 1.0 1.0 1.0 )
        }
        Attribute {
            Format: FLOAT3
            Tag: "specular"
            Value: ( 0.05 0.05 0.05 )
        }
        Attribute {
            Format: FLOAT
            Tag: "shininess"
            Value: ( 30.0 )
        }
        Attribute {
            Format: FLOAT
            Tag: "add_ambient"
            Value: ( 0.0 )
        }
        Attribute {
            Format: FLOAT
            Tag: "reflection"
            Value: ( 0.0 )
        }
        Attribute {
            Format: FLOAT2
            Tag: "aux[5]"
            Value: ( 10000.0 10.0 )
        }
        Texture {
            Tag: "texture[0]:texture_base"
            Value: "/vehicle/truck/passenger_hud/share/hud_ui"
        }
    }
    Material {
        Alias: "mat_casing"
        Effect: "eut2.dif.spec"
        Flags: 0
        AttributeCount: 5
        TextureCount: 1
        Attribute {
            Format: FLOAT3
            Tag: "diffuse"
            Value: ( 0.08 0.08 0.08 )
        }
        Attribute {
            Format: FLOAT3
            Tag: "specular"
            Value: ( 0.05 0.05 0.05 )
        }
        Attribute {
            Format: FLOAT
            Tag: "shininess"
            Value: ( 25.0 )
        }
        Attribute {
            Format: FLOAT
            Tag: "add_ambient"
            Value: ( 0.0 )
        }
        Attribute {
            Format: FLOAT
            Tag: "reflection"
            Value: ( 0.0 )
        }
        Texture {
            Tag: "texture[0]:texture_base"
            Value: "/vehicle/truck/passenger_hud/share/hud_ui"
        }
    }
}
Variant {
    Name: "default"
    Part {
        Name: "defaultpart"
        AttributeCount: 1
        Attribute {
            Format: INT
            Tag: "visible"
            Value: ( 1 )
        }
    }
}
"@

    return @{ Pim = $sb.ToString(); Pit = $pit }
}

$model = Build-MonitorModel -W $Width -H $Height -D $Depth -B $Bezel

foreach ($fam in $TruckFamilies) {
    # 1. Update src/hud_model_sources
    $srcDir = "src/hud_model_sources/$fam"
    [IO.File]::WriteAllText("$srcDir/dashboard_gps.pim", $model.Pim, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText("$srcDir/dashboard_gps.pit", $model.Pit, [Text.UTF8Encoding]::new($false))

    # 2. Update conversion_tools_2_21/base
    $ctDir = "conversion_tools_2_21/base/vehicle/truck/passenger_hud/$fam"
    [IO.File]::WriteAllText("$ctDir/dashboard_gps.pim", $model.Pim, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText("$ctDir/dashboard_gps.pit", $model.Pit, [Text.UTF8Encoding]::new($false))

    Write-Host "Updated model sources for $fam"
}
