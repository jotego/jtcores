package mem

import(
    "fmt"
    "github.com/jotego/jtframe/def"
)

func (item *MacroEnabled) Enabled(macros map[string]string) bool {
    for _,disabler := range item.Unless {
        if def.Defined(macros,disabler) {
            if verbose { fmt.Printf("Disabled because %s was set\n",disabler)}
            return false
        }
    }
    for _,enabler := range item.When {
        if def.Defined(macros,enabler) {
            if verbose { fmt.Printf("Enabled because %s was set\n",enabler)}
            return true
        }
    }
    return len(item.When)==0
}

func (item *BRAMBus_Ioctl) Enabled(macros map[string]string) bool {
    aux := MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled(macros)
}

func (item *BRAMBus) Enabled(macros map[string]string) bool {
    aux := MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled(macros)
}

func (item *SDRAMBus) Enabled(macros map[string]string) bool {
    aux := MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled(macros)
}