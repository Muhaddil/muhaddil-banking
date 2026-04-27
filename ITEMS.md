['bank_check'] = {
    label       = 'Cheque Bancario',
    weight      = 10,
    stack       = false,
    close       = true,
    description = 'Un cheque bancario al portador. Presenta en cualquier banco para cobrar.',
    client = {
        export = 'muhaddil-banking.useCheck',
    },
},
 
['counterfeit_kit'] = {
    label       = 'Kit de Falsificación',
    weight      = 500,
    stack       = true,
    close       = true,
    description = 'Materiales para falsificar documentos. Ilegal.',
},
