<#
.SYNOPSIS
    ROCCAT_MACRO.ps1 – Class to create Roccat Swarm macro

.DESCRIPTION
    Create Roccat Swarm macro

.AUTHOR
    Silicium
    Silicium Corp

.COPYRIGHT
    © 2026 Silicium. All rights reserved.
    You must credit the author, not use for commercial purposes, and not modify this script without permission.

.LICENSE
    CC BY-NC-ND 4.0
    https://creativecommons.org/licenses/by-nc-nd/4.0/
.VERSION
    1.0.0

.LASTUPDATED
    11/22/2025

.NOTES
    TODO : 
    - Add more keyboard keys ...
    - Add mouse right click ...
    - 0x4057, add more mocros in same file...
    - Add fake key for more delay 
#>
class ROCCAT_MACRO{

    $max_name_len      = 0x28; # 0x50/80 unicode, 80/2 for ASCII = 0x28/40 
    $max_desc_len      = 0x20; # (32)
    $max_delay         = 0xffff;  # (65535)

    $mouse_left_button = [byte]0xF0;
    $Key_U             = [byte]0x18;
    $Key_Fin           = [byte]0x4D;

    $press             = [byte]0x01;
    $release           = [byte]0x02;
    
    $mouse_left_press  = [byte[]](0x00, $this.mouse_left_button, $this.press, 0x00, 0x00)
    $mouserelease      = [byte[]](0x00, $this.mouse_left_button, $this.release, 0x00, 0x00)
    
    $signature = "ROCCAT01";
    
    ROCCAT_MACRO(){}

    [byte[]]KeyPress($delay, $key){

        if($delay -gt $this.max_delay){
            throw ("KeyPress : delay is too big, must be (0 - 65535)")
        }

        $l = [Runtime.InteropServices.Marshal]::SizeOf([int32]0) + 1
        $l += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0) + 1
        $l += [Runtime.InteropServices.Marshal]::SizeOf([int32]0) + 1
        $b = New-Object byte[] $l

        $offset = 0
        [Array]::Copy([byte]0x00, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)
        [Array]::Copy($key, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)
        [Array]::Copy($this.press, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)
        [Array]::Copy([byte[]](0x00,0x00), 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0)

        [Array]::Copy($this.Delay($delay), 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0)
        [Array]::Copy([byte]0x00, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)

        [Array]::Copy([byte]0x00, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)
        [Array]::Copy($key, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)
        [Array]::Copy($this.release, 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([byte]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([byte]0)
        [Array]::Copy([byte[]](0x00,0x00), 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0)
        
        return $b;
    }

    [byte[]]MouseLeftClick($delay){

        if($delay -gt $this.max_delay){
            throw ("MouseLeftClick : delay is too big, must be (0 - 65535)")
        }

        $l = $this.mouse_left_press.Length
        $l += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0) + 1
        $l += $this.mouserelease.Length
        $b = New-Object byte[] $l

        $offset = 0
        [Array]::Copy($this.mouse_left_press, 0, $b, $offset, $this.mouse_left_press.Length)
        $offset += $this.mouse_left_press.Length
        [Array]::Copy([BitConverter]::GetBytes([uint16]$delay), 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0)
        [Array]::Copy([byte]0x00, 0, $b, $offset, 1)
        $offset += 1;
        [Array]::Copy($this.mouserelease, 0, $b, $offset, $this.mouserelease.Length)
        
        return $b;
    }  
    
    [byte[]]Delay($delay){ 
        
        if($delay -gt $this.max_delay){
            throw ("Delay : delay is too big, must be (0 - 65535)")
        }

        $l += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0) + 1
        $b = New-Object byte[] $l
        $offset = 0
        [Array]::Copy([BitConverter]::GetBytes([uint16]$delay), 0, $b, $offset, [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0))
        $offset += [Runtime.InteropServices.Marshal]::SizeOf([UInt16]0)
        [Array]::Copy([byte]0x00, 0, $b, $offset, 1)
        return $b;
    }

    [byte[]]BigEndian($bytes){
        [array]::Reverse($bytes)
        return $bytes;
    }

    [byte[]]NewMacro($name, $description, $actions){

        if($name.Length -gt $this.max_name_len){
            throw ("Macro name max length must be {0} (0x{1:x2})" -f $this.max_name_len, $this.max_name_len)
        }

        if($description.Length -gt $this.max_desc_len){
            throw ("Macro description max length must be {0} (0x{1:x2})" -f $this.max_desc_len, $this.max_desc_len)
        }

        $f = New-Object byte[] 16575;
        $offset = 0

        $b = [System.Text.Encoding]::ASCII.GetBytes($this.signature);
        #$b | Format-Hex | Write-Host
        [Array]::Copy($b, 0, $f, $offset, $b.Count);$offset += $b.Count

        $bs = $this.BigEndian([BitConverter]::GetBytes([int32]1))
        #$bs | Format-Hex | Write-Host
        [Array]::Copy($bs, 0, $f, $offset, $bs.Count);$offset += $bs.Count

        $bs = $this.BigEndian([BitConverter]::GetBytes([System.Text.Encoding]::Unicode.GetByteCount($name)))
        #$bs | Format-Hex | Write-Host
        [Array]::Copy($bs, 0, $f, $offset, $bs.Count);$offset += $bs.Count

        $b = [System.Text.Encoding]::BigEndianUnicode.GetBytes($name)
        #$b | Format-Hex | Write-Host
        [Array]::Copy($b, 0, $f, $offset, $b.Count);$offset += $b.Count

        $bs = $this.BigEndian([BitConverter]::GetBytes([int32]1))
        #$bs | Format-Hex | Write-Host
        [Array]::Copy($bs, 0, $f, $offset, $bs.Count);$offset += $bs.Count

        # This indicate start macro !
        $bs = [BitConverter]::GetBytes([int32]0x4057)
        $bs = $this.BigEndian($bs)
        #$bs | Format-Hex | Write-Host
        [Array]::Copy($bs, 0, $f, $offset, $bs.Count);$offset += $bs.Count

        $b = [byte[]](0x01, 0x00, 0x00, 0x01, 0x00) # <-- 0x01, 0xXX, 0x00, 0x01, 0x00, can be 0x01 ...
        #$b | Format-Hex | Write-Host
        [Array]::Copy($b, 0, $f, $offset, $b.Count);$offset += $b.Count

        $b = [System.Text.Encoding]::ASCII.GetBytes($description);  
        #$b | Format-Hex | Write-Host
        [Array]::Copy($b, 0, $f, $offset, $b.Count);$offset += $b.Count

        $p = 80-$description.Length        
        $b = New-Object byte[] $p
        #$b | Format-Hex | Write-Host
        [Array]::Copy($b, 0, $f, $offset, $b.Count);$offset += $b.Count
        
        $cnt_offset = $offset
        $cnt = 0 # assume is actions count ?
        $b = [byte]0        
        #$b | Format-Hex | Write-Host
        [Array]::Copy($b, 0, $f, $offset, 1);$offset += 1

        foreach($action in $actions){
            [Array]::Copy($action, 0, $f, $offset, $action.Count);
            $offset += $action.Count

            if($action.Count -eq 13){
                $cnt +=2
            }
        }

        [Array]::Copy([byte]$cnt, 0, $f, $cnt_offset, 1);

        return $f

    }
}
