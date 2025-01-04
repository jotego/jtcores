package mem

import(
    "fmt"
    "github.com/jotego/jtframe/def"
)

func (item *MacroEnabled) Enabled() bool {
    for _,disabler := range item.Unless {
        if def.Macros.IsSet(disabler) {
            if verbose { fmt.Printf("Disabled because %s was set\n",disabler)}
            return false
        }
    }
    for _,enabler := range item.When {
        if def.Macros.IsSet(enabler) {
            if verbose { fmt.Printf("Enabled because %s was set\n",enabler)}
            return true
        }
    }
    return len(item.When)==0
}

func (item *BRAMBus_Ioctl) Enabled() bool {
    aux := MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (item *BRAMBus) Enabled() bool {
    aux := MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}

func (item *SDRAMBus) Enabled() bool {
    aux := MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}